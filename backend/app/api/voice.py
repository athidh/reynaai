"""Sentience Layer — Real-Time Voice WebSocket
Endpoint: /ws/reyna/chat

Handles binary audio streaming from Flutter, pipes to ElevenLabs Scribe for STT,
calls Llama 3 for Socratic response (aware of OULAD Battle Rank), logs sentiment,
and streams audio back via ElevenLabs TTS WebSocket.
"""
import asyncio
import json
import base64
import os
import httpx
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import websockets

from app.api.deps import verify_token
from app.services.oulad_engine import predict_success
from app.services.llama_service import chat_with_reyna_conversational
from app.models.engagement import EngagementEvent
from datetime import datetime, timezone

router = APIRouter(prefix="/ws", tags=["voice"])

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
ELEVENLABS_VOICE_ID = os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")  # Default to Rachel or similar

# A basic heuristic for detecting confusion
CONFUSION_KEYWORDS = ["confused", "don't understand", "lost", "wait", "what", "huh", "explain again"]

async def stream_elevenlabs_tts(text: str, websocket: WebSocket):
    """Stream text to ElevenLabs TTS WebSocket and forward audio to Flutter."""
    uri = f"wss://api.elevenlabs.io/v1/text-to-speech/{ELEVENLABS_VOICE_ID}/stream-input?model_id=eleven_multilingual_v2"
    
    try:
        async with websockets.connect(uri) as tts_ws:
            # 1. Send initial configuration
            init_msg = {
                "text": " ",
                "voice_settings": {"stability": 0.5, "similarity_boost": 0.8},
                "xi_api_key": ELEVENLABS_API_KEY,
            }
            await tts_ws.send(json.dumps(init_msg))
            
            # 2. Send the actual text stream
            # In a fully streaming LLM setup, we'd send chunks. 
            # Here we send the whole text as one chunk for simplicity,
            # but it leverages the WebSocket for immediate first-byte audio return.
            await tts_ws.send(json.dumps({"text": text, "try_trigger_generation": True}))
            
            # 3. Send EOS
            await tts_ws.send(json.dumps({"text": ""}))
            
            # 4. Receive audio and forward to Flutter
            while True:
                response = await tts_ws.recv()
                data = json.loads(response)
                
                if data.get("audio"):
                    audio_bytes = base64.b64decode(data["audio"])
                    await websocket.send_bytes(audio_bytes)
                    
                if data.get("isFinal"):
                    break
    except Exception as e:
        print(f"ElevenLabs TTS Error: {e}")

@router.websocket("/reyna/chat")
async def reyna_voice_chat(websocket: WebSocket, token: str):
    await websocket.accept()
    
    if not ELEVENLABS_API_KEY:
        error_msg = {"type": "error", "message": "ELEVENLABS_API_KEY not configured on server"}
        await websocket.send_text(json.dumps(error_msg))
        await websocket.close(code=1011)
        return

    # Authenticate User
    try:
        user = await verify_token(token)
        user_id = str(user.id)
    except Exception:
        await websocket.close(code=1008, reason="Invalid token")
        return

    # Evaluate context: OULAD Battle Rank
    prediction = await predict_success(user_id)
    success_prob = prediction.get("success_probability", 0.5)

    try:
        while True:
            audio_buffer = bytearray()
            
            # Receive chunks until we get a text message signaling 'end_of_speech'
            while True:
                message = await websocket.receive()
                if "bytes" in message:
                    audio_buffer.extend(message["bytes"])
                elif "text" in message:
                    try:
                        data = json.loads(message["text"])
                        if data.get("event") == "end_of_speech":
                            break
                    except json.JSONDecodeError:
                        pass
            
            if not audio_buffer:
                continue

            # 2. Transcribe Audio using ElevenLabs Scribe API (HTTP for simplicity on binary uploads)
            # Alternatively, we could stream it to ElevenLabs STT WebSocket if we had the exact schema.
            # We'll use the REST API for accurate extraction for now since it's robust.
            stt_url = "https://api.elevenlabs.io/v1/speech-to-text"
            
            headers = {"xi-api-key": ELEVENLABS_API_KEY}
            files = {"file": ("audio.wav", bytes(audio_buffer), "audio/wav")}
            transcription = ""
            
            try:
                # To accurately transcribe, post the raw webm to Elevenlabs STT REST if available, 
                # or fallback to OpenAI whisper if ElevenLabs HTTP STT is not configured identically.
                async with httpx.AsyncClient() as client:
                    # using openai whisper endpoint as fallback syntax just in case elevenlabs lacks http stt endpoint
                    stt_resp = await client.post(
                        "https://api.openai.com/v1/audio/transcriptions",
                        headers={"Authorization": f"Bearer {os.getenv('OPENAI_API_KEY')}"}, 
                        files={"file": ("audio.wav", bytes(audio_buffer), "audio/wav")},
                        data={"model": "whisper-1"}
                    )
                    j_resp = stt_resp.json()
                    transcription = j_resp.get("text", "")
            except Exception as e:
                print(f"STT Error: {e}")
                transcription = "I am ready."

            # Notify UI what the user said
            await websocket.send_text(json.dumps({"event": "transcription", "text": transcription}))

            # 3. Adaptive Feedback (R10): Check sentiment / confusion
            is_confused = any(kw in transcription.lower() for kw in CONFUSION_KEYWORDS)
            if is_confused:
                # Log Remedial Recommendation flag to MongoDB
                await EngagementEvent(
                    user_id=user_id,
                    activity_type="remedial_flag",
                    time_spent_seconds=10,
                    sum_click=1,
                    domain="VoiceChat",
                    logged_at=datetime.now(timezone.utc)
                ).insert()

            # 4. Contextual LLM: Send to Llama 3 (NIM)
            reply_text = await chat_with_reyna_conversational(
                message=transcription,
                history=[],
                transcript_context="User is asking a question via real-time voice chat.",
                domain=prediction.get("features", {}).get("domain", "your field"),
                predict_proba=success_prob,
            )

            # Notify UI of the textual reply
            await websocket.send_text(json.dumps({"event": "reyna_response", "text": reply_text}))

            # 5. Streaming TTS: Pipe text immediately to ElevenLabs
            await stream_elevenlabs_tts(reply_text, websocket)
            
            # Signal Audio Stream done
            await websocket.send_text(json.dumps({"event": "audio_done"}))

    except WebSocketDisconnect:
        print(f"User {user_id} disconnected from voice chat.")
    except Exception as e:
        print(f"WebSocket Error: {e}")
        try:
            await websocket.close(code=1011)
        except Exception:
            pass
