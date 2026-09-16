# Logos product brief

Logos is a place to practice difficult conversations.

The loop is **Choose → Practice → Reflect → Practice again**.

The product behaves as a mirror before it behaves as a judge. After a session, the person the user just spoke with explains—in first person and with reference to specific moments—what it was like to be on the other side of the conversation. Only after that beat should scores, XP, streaks, achievements, and progression appear.

## Product rules

- Simulation before instruction.
- Consequences over correctness.
- The role-play character stays in role and never acts like an assistant.
- The character provides the primary qualitative reflection; there is no competing coach voice.
- Practice is time-boxed, calm, voice-first, and replayable.
- Home recommends three challenges from a broader scenario library using the user's progression.
- Gamification represents observable mastery and stays secondary to the human moment.
- The practice interface removes everything that is not the conversation.
- Language is warm and human, never clinical, therapeutic, or HR-like.

## AI architecture

All AI processing uses OpenAI:

- OpenAI Realtime API for live speech-to-speech role-play and transcripts.
- OpenAI Responses API with strict structured output for first-person reflection, scores, and transcript-grounded achievements.

Keep providers and scenario primitives reusable. Do not hardcode the app around a single conversation.
