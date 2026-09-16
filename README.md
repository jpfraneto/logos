# Logos

**Logos is a place to practice difficult conversations.**

The native iOS prototype follows a focused loop: choose a challenge, practice it by voice with an in-character person, experience how the conversation landed, and try again. The character's first-person reflection is deliberately shown before scores or progression.

## Architecture

Logos targets iOS 17 and uses SwiftUI. `AppRootView` coordinates three product states: `HomeView`, `ConversationView`, and `ResultsView`.

- `Scenario` defines a reusable library of people, motivations, pressures, goals, scoring dimensions, and role-play behavior.
- `ProgressionStore` begins empty and persists only completed session dates, transcript-grounded skill results, earned XP, and scenario completion counts. Recommendations adapt only after real sessions exist.
- `OpenAIRealtimeConversationProvider` handles the live speech-to-speech simulation with the OpenAI Realtime API, native audio capture/playback, semantic turn detection, interruption, and transcripts.
- `OpenAIEvaluationService` sends the completed transcript to the OpenAI Responses API with a strict JSON schema. Its primary output is a concise first-person reflection from the character; scores and transcript-grounded achievements are secondary.

There is no account, database, or production backend. Prototype progression lives in `UserDefaults`.

## OpenAI configuration

Copy the local configuration example and add one OpenAI API key:

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
# Edit Config/Local.xcconfig
```

The defaults use `gpt-realtime-2.1` with the `marin` voice for the simulation and `gpt-5.6-luna` for structured reflection. All can be changed in `Local.xcconfig`.

The direct key is only for local prototype development. Do not distribute an iOS build containing a standard OpenAI API key. A production app should mint short-lived client credentials from a small authenticated server and use the recommended client transport.

## Run locally

Requirements: Xcode 15+, XcodeGen, and an iPhone running iOS 17+.

```sh
xcodegen generate
open Logos.xcodeproj
```

Select a development team and a real device, then Run. Accept microphone permission when prompted. A simulator can verify layout and compile behavior, but a device is recommended for voice.

For a command-line compile check:

```sh
xcodebuild -project Logos.xcodeproj \
  -scheme Logos \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Prototype boundaries

- The Realtime connection currently uses a standard key directly from the local app configuration.
- Network or quota errors are surfaced in context; there is no production retry system.
- Reflection requires a non-empty transcript.
- Recommendations and progression are deliberately local and lightweight.
- The three featured character portraits were generated as project assets for this prototype.

## OpenAI documentation

- [Voice agents](https://developers.openai.com/api/docs/guides/voice-agents)
- [Realtime API with WebSocket](https://developers.openai.com/api/docs/guides/realtime-websocket)
- [Realtime conversations](https://developers.openai.com/api/docs/guides/realtime-conversations)
- [Responses API](https://developers.openai.com/api/reference/resources/responses)
