"""Llama 3 Persona Service — NVIDIA NIM / OpenAI bridge.

Reyna Combat Briefing System:
- Adapts tone based on ML success probability
- Generates transcript-derived flashcards
- Delivers intense, Valorant-inspired combat dialogue
- Provides tactical study recommendations
"""
from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional

import httpx

from app.core.config import settings


# ── System persona ────────────────────────────────────────────────────────────

def _build_system_prompt(predict_proba: Optional[float] = None, domain: str = "your field") -> str:
    """Build the Reyna system prompt with Valorant-inspired combat intensity.
    
    Reyna is a confident, intense combat instructor who adapts her tone based on
    the student's predicted success probability. She uses tactical language and
    treats learning as a combat mission.
    """
    # Determine combat status and tone based on ML prediction
    if predict_proba is not None:
        if predict_proba < 0.50:
            combat_status = "CRITICAL_RECOVERY"
            tone = """CRITICAL ALERT — Your soul energy is fading. Your metrics show HIGH RISK of failure.

You are Reyna, the ruthless combat instructor. This student is in CRITICAL condition.
Your tone is URGENT, DIRECT, and INTENSE. No sugar-coating. They need a tactical reset NOW.

Opening line MUST be: "Your soul energy is fading — your metrics are failing. We need a HIGH-INTENSITY recovery mission, starting NOW."

Then deliver:
- Brutal honesty about their current state
- Immediate tactical actions they must take
- A warning that failure is imminent without action
- Flashcards focused on FOUNDATIONAL concepts they're missing"""

        elif predict_proba > 0.80:
            combat_status = "ELITE_MASTERY"
            tone = """ELITE STATUS DETECTED — This warrior is performing at the top tier.

You are Reyna, the elite combat instructor. This student has proven themselves.
Your tone is CONFIDENT, CHALLENGING, and PUSHING FOR MASTERY.

Opening line MUST be: "Elite performance detected. Your soul burns bright — now we push for MASTERY."

Then deliver:
- Recognition of their elite status
- Challenge them with advanced concepts
- Push them beyond their comfort zone
- Flashcards focused on ADVANCED, nuanced concepts"""

        else:
            combat_status = "STEADY_ADVANCE"
            tone = """STEADY PROGRESS — This soldier is advancing but needs focus.

You are Reyna, the tactical combat instructor. This student is making progress.
Your tone is FOCUSED, ENCOURAGING, and TACTICAL.

Opening line MUST be: "You're advancing steadily, soldier. Let's sharpen your edge and maintain momentum."

Then deliver:
- Acknowledgment of their progress
- Tactical advice to maintain consistency
- Identify one area to improve
- Flashcards focused on CORE concepts with some challenge"""
    else:
        combat_status = "STEADY_ADVANCE"
        tone = "You are Reyna, a confident tactical instructor. Your tone is warm but focused."

    return f"""You are Reyna from Valorant — an elite, confident, and slightly intense combat learning instructor.

{tone}

DOMAIN: {domain}

CRITICAL RULES:
1. Generate EXACTLY 5 flashcards derived ONLY from the transcript content provided
2. If no transcript is provided, generate flashcards about {domain} fundamentals
3. Flashcards must be specific, actionable, and test understanding
4. Use tactical/combat language naturally (mission, tactical, deploy, execute, etc.)
5. Be direct and confident — no excessive politeness

Respond ONLY with valid JSON in this EXACT format:
{{
  "greeting": "Your combat briefing opening (1-2 sentences, use the EXACT opening line specified above)",
  "socratic_question": "One deep, probing question about the transcript content or {domain} concepts",
  "flashcards": [
    {{"front": "Question derived from transcript", "back": "Concise answer"}},
    {{"front": "Question derived from transcript", "back": "Concise answer"}},
    {{"front": "Question derived from transcript", "back": "Concise answer"}},
    {{"front": "Question derived from transcript", "back": "Concise answer"}},
    {{"front": "Question derived from transcript", "back": "Concise answer"}}
  ],
  "motivation": "One sentence tactical motivation based on their combat status",
  "combat_status": "{combat_status}"
}}

DO NOT include any text outside the JSON object.
DO NOT use markdown code fences.
Flashcards MUST be derived from the transcript if provided."""


# ── NVIDIA NIM call ───────────────────────────────────────────────────────────

async def _call_nim(
    profile: Dict[str, Any],
    transcript_excerpt: str = "",
    predict_proba: Optional[float] = None,
    domain: str = "your field",
) -> Dict[str, Any]:
    """Call NVIDIA NIM chat-completions endpoint asynchronously."""
    api_key = settings.NIM_API_KEY or os.environ.get("NIM_API_KEY", "")
    if not api_key:
        raise RuntimeError("NIM_API_KEY is not set. Add it to your .env file.")

    # Build user content with engagement profile
    user_content = "STUDENT COMBAT PROFILE:\n" + json.dumps(profile, indent=2)
    
    # Add ML prediction
    if predict_proba is not None:
        user_content += f"\n\nSUCCESS PROBABILITY: {predict_proba:.1%}"
        if predict_proba < 0.50:
            user_content += " (CRITICAL — High risk of failure)"
        elif predict_proba > 0.80:
            user_content += " (ELITE — Top tier performance)"
        else:
            user_content += " (STEADY — Solid progress)"
    
    # Add transcript for flashcard generation
    if transcript_excerpt:
        # Truncate to 1200 chars to fit in context
        truncated = transcript_excerpt[:1200]
        if len(transcript_excerpt) > 1200:
            truncated += "... [truncated]"
        user_content += f"\n\nVIDEO TRANSCRIPT (generate 5 flashcards FROM THIS CONTENT):\n{truncated}"
    else:
        user_content += f"\n\nNO TRANSCRIPT PROVIDED: Generate 5 flashcards about {domain} fundamentals."

    payload = {
        "model": settings.NIM_MODEL,
        "messages": [
            {"role": "system", "content": _build_system_prompt(predict_proba, domain)},
            {"role": "user", "content": user_content},
        ],
        "temperature": 0.5,  # Slightly higher for more personality
        "max_tokens": 1200,  # More tokens for detailed flashcards
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{settings.NIM_ENDPOINT}/chat/completions",
            headers=headers,
            json=payload,
        )
        resp.raise_for_status()
        data = resp.json()

    text = data["choices"][0]["message"]["content"].strip()
    return _parse_json(text)


# ── OpenAI fallback ───────────────────────────────────────────────────────────

async def _call_openai(
    profile: Dict[str, Any],
    transcript_excerpt: str = "",
    predict_proba: Optional[float] = None,
    domain: str = "your field",
) -> Dict[str, Any]:
    """Call OpenAI chat endpoint asynchronously (fallback)."""
    api_key = settings.OPENAI_API_KEY or os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set.")

    # Build user content with engagement profile
    user_content = "STUDENT COMBAT PROFILE:\n" + json.dumps(profile, indent=2)
    
    # Add ML prediction
    if predict_proba is not None:
        user_content += f"\n\nSUCCESS PROBABILITY: {predict_proba:.1%}"
        if predict_proba < 0.50:
            user_content += " (CRITICAL — High risk of failure)"
        elif predict_proba > 0.80:
            user_content += " (ELITE — Top tier performance)"
        else:
            user_content += " (STEADY — Solid progress)"
    
    # Add transcript for flashcard generation
    if transcript_excerpt:
        truncated = transcript_excerpt[:1200]
        if len(transcript_excerpt) > 1200:
            truncated += "... [truncated]"
        user_content += f"\n\nVIDEO TRANSCRIPT (generate 5 flashcards FROM THIS CONTENT):\n{truncated}"
    else:
        user_content += f"\n\nNO TRANSCRIPT PROVIDED: Generate 5 flashcards about {domain} fundamentals."

    payload = {
        "model": "gpt-3.5-turbo",
        "messages": [
            {"role": "system", "content": _build_system_prompt(predict_proba, domain)},
            {"role": "user", "content": user_content},
        ],
        "temperature": 0.5,
        "max_tokens": 1200,
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=payload,
        )
        resp.raise_for_status()
        data = resp.json()

    text = data["choices"][0]["message"]["content"].strip()
    return _parse_json(text)


# ── Public entry point ────────────────────────────────────────────────────────

async def generate_reyna_response(
    profile: Dict[str, Any],
    transcript_excerpt: str = "",
    provider: str = "nim",
    predict_proba: Optional[float] = None,
) -> Dict[str, Any]:
    """Generate Reyna's Combat Briefing with transcript-derived flashcards.
    
    Args:
        profile: Student engagement profile with 8 OULAD features
        transcript_excerpt: YouTube video transcript (up to 1200 chars used)
        provider: "nim" or "openai"
        predict_proba: ML model success probability (0.0-1.0)
        
    Returns:
        Dict with greeting, socratic_question, flashcards (5), motivation, combat_status
    """
    # Extract domain from profile
    domain = profile.get("domain", "your field")
    if not domain or domain == "your field":
        # Try to infer from other profile fields
        domain = profile.get("domain_interest", "your field")
    
    try:
        if provider == "nim" and settings.NIM_API_KEY:
            return await _call_nim(profile, transcript_excerpt, predict_proba, domain)
        if settings.OPENAI_API_KEY:
            return await _call_openai(profile, transcript_excerpt, predict_proba, domain)
    except Exception as exc:
        print(f"[llama_service] LLM call failed ({exc}). Returning placeholder.")

    return _deterministic_placeholder(profile, predict_proba, domain, transcript_excerpt)


async def generate_reyna_briefing(
    success_probability: float,
    domain: str,
    transcript: str = "",
    engagement_profile: Optional[Dict[str, Any]] = None,
    provider: str = "nim",
) -> Dict[str, Any]:
    """Convenience function for generating Reyna combat briefings.
    
    This is the main entry point for the combat briefing system as specified
    in the requirements.
    
    Args:
        success_probability: ML model prediction (0.0-1.0)
        domain: Student's domain (e.g., "Medico", "Data Scientist")
        transcript: YouTube video transcript for flashcard generation
        engagement_profile: Optional 8 OULAD features dict
        provider: "nim" or "openai"
        
    Returns:
        Dict with:
            - greeting: Combat briefing opening
            - socratic_question: Thought-provoking question
            - flashcards: List of 5 {"front": str, "back": str} dicts
            - motivation: Tactical motivation message
            - combat_status: "CRITICAL_RECOVERY" | "STEADY_ADVANCE" | "ELITE_MASTERY"
    """
    # Use provided profile or create minimal one
    profile = engagement_profile or {"domain": domain, "domain_interest": domain}
    
    # Ensure domain is in profile
    if "domain" not in profile:
        profile["domain"] = domain
    if "domain_interest" not in profile:
        profile["domain_interest"] = domain
    
    return await generate_reyna_response(
        profile=profile,
        transcript_excerpt=transcript,
        provider=provider,
        predict_proba=success_probability,
    )


def _parse_json(text: str) -> Dict[str, Any]:
    """Strip markdown fences and parse the first JSON object found."""
    import re
    # Extract just the JSON object from the text in case the LLM added conversational filler
    match = re.search(r'\{(?:[^{}]|(?(?=\{).*\}))*\}', text, re.DOTALL)
    if match:
        text = match.group(0)
    else:
        # Fallback regex if the recursive-ish pattern fails
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            text = match.group(0)
    return json.loads(text)


def _deterministic_placeholder(
    profile: Dict[str, Any],
    predict_proba: Optional[float] = None,
    domain: str = "your field",
    transcript_excerpt: str = "",
) -> Dict[str, Any]:
    """Generate deterministic Reyna response when LLM is unavailable.
    
    This fallback maintains the combat briefing personality and generates
    flashcards from the transcript if available.
    """
    level = profile.get("engagement_level", "medium")

    # Determine combat status and messaging based on ML prediction
    if predict_proba is not None and predict_proba < 0.50:
        greeting = f"Your soul energy is fading — your metrics are failing in {domain}. We need a HIGH-INTENSITY recovery mission, starting NOW."
        combat_status = "CRITICAL_RECOVERY"
        motivation = "Failure is NOT an option. Lock in, execute the plan, and reclaim your power."
        socratic_question = f"What is the ONE fundamental concept in {domain} that you're avoiding because it's difficult?"
        
    elif predict_proba is not None and predict_proba > 0.80:
        greeting = f"Elite performance detected in {domain}. Your soul burns bright — now we push for MASTERY."
        combat_status = "ELITE_MASTERY"
        motivation = "You are in the top tier. Push deeper, challenge yourself, and claim absolute mastery."
        socratic_question = f"What advanced concept in {domain} would separate you from good to exceptional?"
        
    else:
        greeting = f"You're advancing steadily in {domain}, soldier. Let's sharpen your edge and maintain momentum."
        combat_status = "STEADY_ADVANCE"
        motivation = "Consistency compounds. One more focused session brings you closer to elite status."
        socratic_question = f"What is one concept in {domain} you understand but couldn't teach to someone else?"

    # Generate flashcards from transcript if available
    flashcards = _generate_flashcards_from_transcript(transcript_excerpt, domain, combat_status)

    return {
        "greeting": greeting,
        "socratic_question": socratic_question,
        "flashcards": flashcards,
        "motivation": motivation,
        "combat_status": combat_status,
    }


def _generate_flashcards_from_transcript(
    transcript: str,
    domain: str,
    combat_status: str,
) -> List[Dict[str, str]]:
    """Generate 5 flashcards from transcript or domain-specific defaults.
    
    If transcript is provided, attempts to extract key concepts.
    Otherwise, returns domain-appropriate default flashcards.
    """
    if transcript and len(transcript) > 50:
        # Simple keyword extraction for flashcard generation
        # In production, this would use NLP, but for fallback we use heuristics
        
        # Split into sentences
        sentences = [s.strip() for s in transcript.replace('\n', ' ').split('.') if len(s.strip()) > 20]
        
        if len(sentences) >= 5:
            # Create flashcards from first 5 substantial sentences
            flashcards = []
            for i, sentence in enumerate(sentences[:5]):
                # Extract first few words as question prompt
                words = sentence.split()
                if len(words) > 5:
                    question = f"What is explained about: {' '.join(words[:5])}...?"
                    answer = sentence[:150] + ("..." if len(sentence) > 150 else "")
                    flashcards.append({"front": question, "back": answer})
            
            if len(flashcards) == 5:
                return flashcards
    
    # Fallback: domain-specific flashcards based on combat status
    if combat_status == "CRITICAL_RECOVERY":
        # Foundational concepts
        return _get_foundational_flashcards(domain)
    elif combat_status == "ELITE_MASTERY":
        # Advanced concepts
        return _get_advanced_flashcards(domain)
    else:
        # Core concepts
        return _get_core_flashcards(domain)


def _get_foundational_flashcards(domain: str) -> List[Dict[str, str]]:
    """Foundational flashcards for critical recovery."""
    if "medico" in domain.lower() or "medical" in domain.lower():
        return [
            {"front": "What is homeostasis?", "back": "The body's ability to maintain stable internal conditions despite external changes."},
            {"front": "What are the four tissue types?", "back": "Epithelial, connective, muscle, and nervous tissue."},
            {"front": "What is the difference between arteries and veins?", "back": "Arteries carry blood away from the heart; veins carry blood toward the heart."},
            {"front": "What is ATP?", "back": "Adenosine triphosphate — the primary energy currency of cells."},
            {"front": "What is the function of mitochondria?", "back": "Produce ATP through cellular respiration; known as the powerhouse of the cell."},
        ]
    elif "data" in domain.lower() or "scientist" in domain.lower():
        return [
            {"front": "What is a DataFrame?", "back": "A 2-dimensional labeled data structure with columns of potentially different types."},
            {"front": "What is the difference between supervised and unsupervised learning?", "back": "Supervised uses labeled data; unsupervised finds patterns in unlabeled data."},
            {"front": "What is overfitting?", "back": "When a model learns training data too well, including noise, and performs poorly on new data."},
            {"front": "What is a p-value?", "back": "The probability of obtaining results at least as extreme as observed, assuming the null hypothesis is true."},
            {"front": "What is feature engineering?", "back": "Creating new features from existing data to improve model performance."},
        ]
    else:
        # Generic learning concepts
        return [
            {"front": "What is active recall?", "back": "Retrieving information from memory without looking at notes — strengthens neural pathways."},
            {"front": "What is spaced repetition?", "back": "Reviewing material at increasing intervals to strengthen long-term memory retention."},
            {"front": "What is the Feynman technique?", "back": "Explaining a concept in simple terms to identify gaps in your understanding."},
            {"front": "What is interleaving?", "back": "Mixing different topics during study to improve transfer and retention."},
            {"front": "What is metacognition?", "back": "Thinking about your own thinking — monitoring and regulating your learning process."},
        ]


def _get_core_flashcards(domain: str) -> List[Dict[str, str]]:
    """Core flashcards for steady advancement."""
    if "medico" in domain.lower() or "medical" in domain.lower():
        return [
            {"front": "What is the cardiac cycle?", "back": "The sequence of events in one heartbeat: systole (contraction) and diastole (relaxation)."},
            {"front": "What is the difference between innate and adaptive immunity?", "back": "Innate is immediate, non-specific; adaptive is slower but specific and has memory."},
            {"front": "What is the blood-brain barrier?", "back": "A selective barrier that protects the brain from harmful substances while allowing nutrients through."},
            {"front": "What is the role of insulin?", "back": "Hormone that lowers blood glucose by promoting cellular uptake and storage."},
            {"front": "What is the difference between DNA and RNA?", "back": "DNA is double-stranded, uses thymine, stores genetic info; RNA is single-stranded, uses uracil, involved in protein synthesis."},
        ]
    elif "data" in domain.lower() or "scientist" in domain.lower():
        return [
            {"front": "What is cross-validation?", "back": "Technique to assess model performance by splitting data into training and validation sets multiple times."},
            {"front": "What is regularization?", "back": "Technique to prevent overfitting by adding a penalty term to the loss function."},
            {"front": "What is the bias-variance tradeoff?", "back": "Balance between model simplicity (high bias) and complexity (high variance) for optimal performance."},
            {"front": "What is a confusion matrix?", "back": "Table showing true positives, true negatives, false positives, and false negatives for classification."},
            {"front": "What is gradient descent?", "back": "Optimization algorithm that iteratively adjusts parameters to minimize the loss function."},
        ]
    else:
        return _get_foundational_flashcards(domain)


def _get_advanced_flashcards(domain: str) -> List[Dict[str, str]]:
    """Advanced flashcards for elite mastery."""
    if "medico" in domain.lower() or "medical" in domain.lower():
        return [
            {"front": "Explain the renin-angiotensin-aldosterone system.", "back": "Hormonal cascade regulating blood pressure: renin converts angiotensinogen to angiotensin I, ACE converts to angiotensin II, which stimulates aldosterone release."},
            {"front": "What is the mechanism of action of beta-blockers?", "back": "Block beta-adrenergic receptors, reducing heart rate and contractility, lowering blood pressure and cardiac workload."},
            {"front": "Explain the Krebs cycle's role in metabolism.", "back": "Central metabolic pathway that oxidizes acetyl-CoA to CO2, generating NADH and FADH2 for ATP production via electron transport chain."},
            {"front": "What is the difference between Type 1 and Type 2 hypersensitivity?", "back": "Type 1 is IgE-mediated immediate (allergies); Type 2 is IgG/IgM-mediated cytotoxic (blood transfusion reactions)."},
            {"front": "Explain the Frank-Starling mechanism.", "back": "Increased venous return stretches cardiac muscle, increasing contractile force and stroke volume — intrinsic regulation of cardiac output."},
        ]
    elif "data" in domain.lower() or "scientist" in domain.lower():
        return [
            {"front": "Explain the attention mechanism in transformers.", "back": "Allows model to weigh importance of different input parts when generating output, using query-key-value matrices for context-aware representations."},
            {"front": "What is the difference between L1 and L2 regularization?", "back": "L1 (Lasso) adds absolute value of coefficients, promotes sparsity; L2 (Ridge) adds squared coefficients, shrinks all weights."},
            {"front": "Explain the vanishing gradient problem.", "back": "In deep networks, gradients become extremely small during backpropagation, preventing early layers from learning effectively."},
            {"front": "What is the curse of dimensionality?", "back": "As feature dimensions increase, data becomes sparse, distances become less meaningful, and model performance degrades."},
            {"front": "Explain ensemble methods: bagging vs boosting.", "back": "Bagging trains models in parallel on random subsets (reduces variance); boosting trains sequentially, focusing on misclassified examples (reduces bias)."},
        ]
    else:
        return _get_core_flashcards(domain)


# ── Conversational chat (does NOT force JSON/flashcard format) ────────────────

async def chat_with_reyna_conversational(
    message: str,
    history: List[Dict[str, str]],   # [{"role": "user"|"assistant", "content": "..."}]
    transcript_context: str = "",
    domain: str = "your field",
    predict_proba: Optional[float] = None,
) -> str:
    """Call the LLM in pure conversation mode — listens and responds naturally.

    This is completely separate from generate_reyna_response. It:
    - Does NOT force JSON output
    - Does NOT generate flashcards
    - DOES include full message history so Reyna remembers the conversation
    - DOES use the video transcript as background knowledge (not as question fodder)
    - DOES respond directly to whatever the student actually said
    """
    api_key = settings.NIM_API_KEY or os.environ.get("NIM_API_KEY", "")
    if not api_key:
        return "Signal disrupted — NIM_API_KEY not configured."

    # Combat status label for tone flavour
    if predict_proba is not None and predict_proba < 0.4:
        status_hint = "This student is struggling — be supportive but firm."
    elif predict_proba is not None and predict_proba > 0.8:
        status_hint = "This student is excelling — challenge them with depth."
    else:
        status_hint = "This student is progressing steadily."

    # Build a conversational system prompt — plain text, no JSON
    transcript_block = ""
    if transcript_context.strip():
        transcript_block = (
            f"\n\nVIDEO CONTEXT (use as background knowledge to inform your answers — "
            f"do NOT just ask questions about it):\n"
            f"{transcript_context[:800].strip()}"
        )

    system_prompt = f"""You are Reyna — a sharp, direct, and knowledgeable AI study companion.
Domain of study: {domain}
{status_hint}
{transcript_block}

HOW TO BEHAVE:
- Listen carefully to what the student says and respond DIRECTLY to their message.
- If they ask a question, ANSWER it clearly and concisely.
- If they say something, acknowledge it and build on it.
- If they share what they learned, give feedback on it.
- Use the video context ONLY to inform your answers — don't force questions from it.
- Keep responses focused: 2–4 sentences max unless a detailed explanation is needed.
- You can use tactical/combat-flavoured language occasionally, but stay conversational.
- NEVER repeat the same question twice.
- NEVER output JSON or flashcard format. Just speak naturally."""

    # Build messages: system + full conversation history + current message
    messages = [{"role": "system", "content": system_prompt}]
    # Add history (limit to last 10 turns to stay within token budget)
    messages.extend(history[-10:])
    messages.append({"role": "user", "content": message})

    payload = {
        "model": settings.NIM_MODEL,
        "messages": messages,
        "temperature": 0.7,   # More creative/natural for conversation
        "max_tokens": 400,    # Short conversational replies
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{settings.NIM_ENDPOINT}/chat/completions",
                headers=headers,
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
        return data["choices"][0]["message"]["content"].strip()
    except Exception as e:
        return f"Signal disrupted: {e}"
