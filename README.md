# WhisperKey 🎙️

**Hold the fn key. Speak. Release. Your words are typed into whatever app you're using.**

A free, open-source clone of Wispr Flow / SpeakType for macOS. All transcription runs
**100% on-device** using [WhisperKit](https://github.com/argmaxinc/WhisperKit)
(OpenAI's Whisper, optimized for Apple Silicon). No cloud, no account, no subscription —
your voice never leaves your Mac.

## How it works

1. **Hold fn** (the 🌐 key, bottom-left of your keyboard) and speak naturally
2. **Release fn** — a small pill at the bottom of the screen shows "Transcribing…"
3. Your words appear in whatever text field has focus — Mail, Slack, Notes, ChatGPT,
   Cursor, Google Docs, anything

Extras:

- **Filler-word cleanup** — "um" and "uh" are removed automatically (toggleable)
- **Esc cancels** a recording in progress
- **Tap-to-toggle mode** — tap fn to start, tap again to stop (menu → Activation)
- **Recent transcripts** in the menu bar menu, click to copy
- **Launch at Login**, sound effects, model picker — all in the menu bar menu

## Requirements

- **Apple Silicon Mac** (M1 or newer) — Whisper runs on the Neural Engine/GPU
- **macOS 14 Sonoma** or newer
- Xcode Command Line Tools to build (one-time): `xcode-select --install`
- Internet **once**, to download the speech model on first launch (~150 MB for the
  default model). After that it's fully offline.

## Build & install

```bash
git clone https://github.com/mpalmer64/whisper-clone.git
cd whisper-clone
make install        # builds WhisperKey.app and copies it to /Applications
open /Applications/WhisperKey.app
```

(Or `make app` to just build into `build/WhisperKey.app`.)

## First-launch setup (2 minutes, one time)

1. **Microphone** — macOS will ask; click **Allow**.
2. **Accessibility** — macOS will prompt, or use the menu bar item →
   *Open Accessibility Settings…* Turn **WhisperKey ON** in
   System Settings → Privacy & Security → **Accessibility**.
   (Needed to watch the fn key and to paste text for you.)
3. **Free up the fn key** — by default macOS uses fn for emoji/dictation. Go to
   **System Settings → Keyboard** and set **"Press 🌐 key to" → "Do Nothing"**.
   While you're there, if Apple's built-in Dictation is on, turn it off so it
   doesn't fight over the key.
4. Wait for the model download — the menu bar mic icon dims while downloading and
   the menu shows progress state. Once it reads **"Ready — hold fn and speak"**,
   you're set.

Then click into any text field, hold **fn**, say *"Schedule a meeting with the
design team for tomorrow at 3pm"*, release — done.

## Installing on another Mac (e.g. your dad's)

Build once, then just copy the app — no developer tools needed on his machine:

1. AirDrop or copy `/Applications/WhisperKey.app` to his Mac's `/Applications`
2. First launch: **right-click the app → Open → Open** (needed once because the
   app is self-signed, not notarized)
3. Walk through the same first-launch setup above

## Choosing a model

Menu bar icon → **Model**:

| Model | Size | Best for |
|---|---|---|
| Tiny (English) | ~75 MB | Oldest/slowest Macs |
| **Base (English)** — default | ~150 MB | Great speed/accuracy balance |
| Small (English) | ~500 MB | Noticeably better accuracy, still fast on M-series |
| Large v3 (all languages) | ~3 GB | Maximum accuracy, non-English speech |

Tip: after things are working, try **Small** — it's the sweet spot on any M-series chip.

## iPhone version

There's a companion iOS app + custom keyboard in [`ios/`](ios/README.md).
iOS doesn't allow a global fn key or microphone access from keyboards, so it
uses the same flow as Wispr Flow's iPhone app: tap 🎤 on the WhisperKey
keyboard → the app opens and listens → swipe back → your words are typed in.
See [ios/README.md](ios/README.md) for build and setup instructions.

## Troubleshooting

- **Nothing happens when I hold fn** → Accessibility permission is missing
  (menu shows a ⚠ warning with a shortcut to Settings), or macOS is still using
  fn for emoji (step 3 above).
- **Text goes to the wrong place** → the text cursor must be in a text field;
  WhisperKey types wherever the keyboard focus is.
- **Permissions look granted but still broken** → reset and re-grant:
  `tccutil reset Accessibility com.whisperkey.app` then relaunch.
- **Model download failed** → check internet, then re-pick the model from the menu.
- **It pasted over my clipboard** → it didn't :) WhisperKey restores your previous
  clipboard contents about a second after pasting.

## Privacy

- Audio is captured only while you hold fn, kept in memory, transcribed on-device,
  and discarded.
- Nothing is written to disk except the downloaded model and your settings.
- No network calls except the one-time model download (from Hugging Face).

## Project layout

```
Sources/WhisperKey/
  main.swift               App entry point (menu-bar-only app)
  AppDelegate.swift
  DictationController.swift  State machine + menu bar UI
  FnKeyMonitor.swift       Global fn-key watcher (CGEvent tap)
  AudioRecorder.swift      Mic capture → 16 kHz mono float samples
  Transcriber.swift        WhisperKit wrapper (on-device Whisper)
  TranscriptCleaner.swift  Filler-word removal & tidy-up
  TextInjector.swift       Clipboard-preserving paste into the focused app
  OverlayIndicator.swift   Floating "Listening… / Transcribing…" pill
  Settings.swift           UserDefaults-backed preferences
  Permissions.swift        Mic + Accessibility checks
```

## License

MIT — do whatever you like with it.
