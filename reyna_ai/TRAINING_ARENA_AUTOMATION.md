# Training Arena Automation - Implementation Guide

## Overview

The Training Arena has been fully automated with ML integration, providing an end-to-end learning flow from content discovery to mission updates with real-time success probability tracking.

## Features Implemented

### 1. ✅ Search Integration

**Functionality**: Auto-fetch YouTube content from backend scraper

**Implementation**:
- When user enters a topic (e.g., "Neuroscience") or YouTube URL
- Calls `GET /scraper/fetch-content?query={topic}`
- Automatically extracts `video_id` from response
- Loads video into `YoutubePlayerController`
- Falls back to direct URL/ID if API fails

**Code Location**: `lib/screens/training_screen.dart` - `_searchVideo()` method

**User Flow**:
1. User types "Machine Learning" in search bar
2. Presses Enter or taps bolt icon
3. Backend searches YouTube and returns video
4. Video automatically loads and starts playing

### 2. ✅ Heartbeat Tracking

**Functionality**: Send engagement events every 30 seconds

**Implementation**:
- Timer starts when video begins playing
- Every 30 seconds, sends `POST /tracker/log-event`
- Payload: `sum_click: 5` (represents sustained focus)
- Continues until video ends or user pauses
- Heartbeat count displayed in engagement tracker

**Code Location**: `lib/screens/training_screen.dart` - `_startHeartbeat()`, `_sendHeartbeat()`

**Event Structure**:
```dart
{
  "content_id": "video_id",
  "activity_type": "video",
  "sum_click": 5,  // Sustained focus indicator
  "time_spent_seconds": 30.0,
  "event_type": "heartbeat",
  "domain": "user_domain"
}
```

**Visual Feedback**:
- Heartbeat counter shows number of pings sent
- Updates in real-time in engagement tracker bar

### 3. ✅ Mission Update After Video Ends

**Functionality**: Reload study plan when video completes

**Implementation**:
- Detects video end via `YoutubePlayerController` state
- Logs completion event to `/tracker/log-event`
- Calls `GET /tutor/study-plan` to fetch updated 7-day plan
- Calls `GET /tutor/predict` to refresh success probability
- Shows success notification

**Code Location**: `lib/screens/training_screen.dart` - `_onVideoEnded()` method

**User Flow**:
1. Video reaches end
2. Completion event logged
3. Study plan refreshed in background
4. Success probability updated
5. Snackbar shows "Mission Complete! Study plan updated."
6. Dashboard reflects new data on next visit

### 4. ✅ Success Probability Display

**Functionality**: Show ML prediction with visual bar

**Implementation**:
- Fetches from `GET /tutor/predict` endpoint
- Displays as percentage (e.g., "84% Chance of Promotion")
- Color-coded progress bar:
  - **Green** (≥70%): High success probability
  - **Yellow** (40-69%): Moderate success probability
  - **Red** (<40%): Low success probability
- Shows current rank badge (Iron → Radiant)

**Code Location**: `lib/screens/training_screen.dart` - `_SuccessProbabilityBar` widget

**Visual Design**:
```
┌─────────────────────────────────────────┐
│ SUCCESS PROBABILITY          [DIAMOND]  │
│ 84% Chance of Promotion                 │
│ ████████████████████░░░░░░░░            │
└─────────────────────────────────────────┘
```

### 5. ✅ Rank Animation

**Functionality**: Purple "Level Up" animation on rank increase

**Implementation**:
- Compares previous and current success probability
- Maps probability to rank:
  - **RADIANT** (≥80%)
  - **DIAMOND** (60-79%)
  - **PLATINUM** (40-59%)
  - **GOLD** (20-39%)
  - **IRON** (<20%)
- Triggers animation when rank increases
- Elastic bounce effect with purple glow
- Auto-dismisses after 2 seconds

**Code Location**: `lib/screens/training_screen.dart` - `_LevelUpOverlay` widget

**Animation Sequence**:
1. Detect rank increase (e.g., GOLD → PLATINUM)
2. Overlay fades in with black background
3. Rank badge scales up with elastic curve
4. Purple glow effect around badge
5. Shows "RANK UP!" message
6. Fades out after 2 seconds

**Visual Design**:
```
┌─────────────────────────────────────────┐
│                                         │
│              ↑                          │
│          RANK UP!                       │
│          PLATINUM                       │
│   Your performance is improving!        │
│                                         │
└─────────────────────────────────────────┘
```

## Technical Architecture

### State Management

**AppState Provider** (`lib/providers/app_state.dart`):
- Manages authentication token
- Stores study plan data
- Handles engagement profile
- Provides `logEvent()` method for tracking

**Local State** (`_TrainingScreenState`):
- `_successProbability`: Current ML prediction
- `_previousRank`: Last known rank for comparison
- `_heartbeatTimer`: 30-second interval timer
- `_heartbeatCount`: Number of pings sent
- `_levelUpController`: Animation controller

### API Integration

**Endpoints Used**:
1. `GET /scraper/fetch-content?query={topic}` - Search YouTube
2. `POST /tracker/log-event` - Log engagement events
3. `GET /tutor/predict` - Get ML success probability
4. `GET /tutor/study-plan` - Fetch 7-day study plan

**Error Handling**:
- Graceful fallback to direct URL/ID if scraper fails
- Silent failure for heartbeat events (doesn't interrupt playback)
- Retry logic for critical operations
- User-friendly error messages

### Performance Optimizations

**Efficient Tracking**:
- Heartbeat only sends when video is actively playing
- Timer automatically stops on pause/end
- Minimal UI updates to prevent jank

**Smart Loading**:
- Success probability loaded on screen init
- Refreshed only after video completion
- Cached in state to avoid redundant API calls

**Animation Performance**:
- Uses `SingleTickerProviderStateMixin`
- Hardware-accelerated transforms
- Efficient overlay rendering

## User Experience Flow

### Complete Learning Session

```
1. User opens Training Arena
   ↓
2. Enters "Neural Networks" in search
   ↓
3. Backend fetches relevant YouTube video
   ↓
4. Video auto-loads and starts playing
   ↓
5. Heartbeat starts (every 30s, sum_click: 5)
   ↓
6. User watches video (heartbeats continue)
   ↓
7. Video ends
   ↓
8. Completion event logged
   ↓
9. Study plan refreshed
   ↓
10. Success probability updated
   ↓
11. If rank increased → Level Up animation
   ↓
12. User sees updated stats in Dashboard
```

### Visual Feedback Timeline

```
0:00 - Video starts, heartbeat timer begins
0:30 - First heartbeat sent (count: 1)
1:00 - Second heartbeat sent (count: 2)
1:30 - Third heartbeat sent (count: 3)
...
5:00 - Video ends
5:01 - Completion logged, study plan updated
5:02 - Success probability refreshed
5:03 - Level Up animation (if rank increased)
5:05 - Animation dismisses
```

## Configuration

### Heartbeat Interval

Default: 30 seconds

To change:
```dart
// In _startHeartbeat() method
_heartbeatTimer = Timer.periodic(
  const Duration(seconds: 30), // Change this value
  (timer) { ... }
);
```

### Success Probability Thresholds

Current mapping:
```dart
if (prob >= 0.8) return 'RADIANT';
if (prob >= 0.6) return 'DIAMOND';
if (prob >= 0.4) return 'PLATINUM';
if (prob >= 0.2) return 'GOLD';
return 'IRON';
```

### Animation Duration

Default: 1.5 seconds

To change:
```dart
_levelUpController = AnimationController(
  duration: const Duration(milliseconds: 1500), // Change this
  vsync: this,
);
```

## Testing

### Manual Testing Checklist

- [ ] Search for topic (e.g., "Python Tutorial")
- [ ] Verify video loads automatically
- [ ] Check heartbeat counter increments every 30s
- [ ] Pause video, verify heartbeat stops
- [ ] Resume video, verify heartbeat restarts
- [ ] Let video play to end
- [ ] Verify completion notification appears
- [ ] Check Dashboard for updated study plan
- [ ] Verify success probability displays correctly
- [ ] Test rank animation (may need to simulate rank increase)

### Debug Logging

Enable debug prints:
```dart
debugPrint('[TrainingScreen] Fetching content for: $q');
debugPrint('[Heartbeat] Sending ping #$_heartbeatCount');
debugPrint('[TrainingScreen] Video ended - updating mission');
```

### Common Issues

**Issue**: Heartbeat not sending
- **Solution**: Check if video is actually playing (not paused/buffering)
- **Solution**: Verify authentication token is valid

**Issue**: Video not loading from search
- **Solution**: Check backend scraper API is running
- **Solution**: Verify network connectivity
- **Solution**: Try direct YouTube URL as fallback

**Issue**: Success probability not updating
- **Solution**: Ensure user has engagement events logged
- **Solution**: Check ML model is loaded on backend
- **Solution**: Verify `/tutor/predict` endpoint is accessible

**Issue**: Level Up animation not showing
- **Solution**: Rank must actually increase (not just probability)
- **Solution**: Check `_previousRank` is being tracked correctly
- **Solution**: Verify animation controller is initialized

## Future Enhancements

### Planned Features

1. **Adaptive Heartbeat**: Adjust interval based on video length
2. **Offline Mode**: Cache videos for offline viewing
3. **Playback Speed Tracking**: Log if user watches at 1.5x or 2x
4. **Rewind Detection**: Track if user rewinds to rewatch sections
5. **Transcript Display**: Show synchronized transcript below video
6. **Flashcard Generation**: Auto-generate flashcards from video transcript
7. **Quiz Mode**: Test comprehension after video ends
8. **Social Features**: Share progress with study groups

### Technical Improvements

1. **WebSocket Heartbeat**: Real-time event streaming instead of polling
2. **Local Caching**: Store success probability to reduce API calls
3. **Predictive Loading**: Preload next recommended video
4. **Analytics Dashboard**: Detailed engagement metrics visualization
5. **A/B Testing**: Test different heartbeat intervals for optimal tracking

## Code Structure

```
lib/screens/training_screen.dart
├── TrainingScreen (StatefulWidget)
├── _TrainingScreenState
│   ├── Video Management
│   │   ├── _loadVideo()
│   │   ├── _initPlayer()
│   │   └── _onPlayerStateChange()
│   ├── Heartbeat Tracking
│   │   ├── _startHeartbeat()
│   │   ├── _stopHeartbeat()
│   │   └── _sendHeartbeat()
│   ├── Mission Updates
│   │   ├── _onVideoEnded()
│   │   └── _loadSuccessProbability()
│   ├── Rank System
│   │   ├── _probabilityToRank()
│   │   ├── _rankValue()
│   │   └── _triggerLevelUpAnimation()
│   └── Search Integration
│       └── _searchVideo()
├── _EmptyState (Widget)
├── _SuccessProbabilityBar (Widget)
├── _EventBar (Widget)
└── _LevelUpOverlay (Widget)
```

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  youtube_player_flutter: ^8.1.2
  http: ^1.1.0
```

## API Contract

### POST /tracker/log-event

**Request**:
```json
{
  "content_id": "dQw4w9WgXcQ",
  "activity_type": "video",
  "sum_click": 5,
  "time_spent_seconds": 30.0,
  "event_type": "heartbeat",
  "domain": "Neuroscience"
}
```

**Response**:
```json
{
  "status": "logged",
  "event_id": "507f1f77bcf86cd799439011"
}
```

### GET /tutor/predict

**Response**:
```json
{
  "user_id": "507f1f77bcf86cd799439011",
  "success_probability": 0.84,
  "features": {
    "total_interactions": 150,
    "days_active": 20,
    "engagement_score": 0.68
  },
  "demographics": {
    "age_band": "0-35",
    "education": "A Level"
  },
  "model_available": true
}
```

### GET /tutor/study-plan

**Response**:
```json
{
  "user_id": "507f1f77bcf86cd799439011",
  "success_probability": 0.84,
  "daily_minutes": 60,
  "days": [
    {
      "day": 1,
      "focus": "Review notes",
      "recommended_minutes": 60,
      "tasks": ["Skim lecture notes", "Make summary sheet"],
      "tip": "Short daily sessions beat long infrequent ones."
    }
  ]
}
```

## Success Metrics

### Key Performance Indicators

1. **Engagement Rate**: % of videos watched to completion
2. **Heartbeat Consistency**: Average heartbeats per video
3. **Success Probability Trend**: Week-over-week improvement
4. **Rank Progression**: Time to reach each rank
5. **Mission Completion**: % of study plan tasks completed

### Analytics Events

All events are logged to `/tracker/log-event`:
- `heartbeat`: Every 30 seconds during playback
- `pause`: When user pauses video
- `complete`: When video reaches end
- `seek`: When user skips forward/backward (future)

## Conclusion

The Training Arena automation provides a seamless, ML-driven learning experience that:
- Eliminates manual content searching
- Tracks engagement automatically
- Provides real-time performance feedback
- Motivates through gamification (ranks, animations)
- Adapts study plans based on ML predictions

This creates a "Combat Learning" environment where students are constantly aware of their progress and motivated to improve.
