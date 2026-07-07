# WhisperKey for iPhone 📱

A custom keyboard + companion app that brings WhisperKey dictation to iOS —
the same on-device Whisper transcription as the Mac app.

## Why it works differently than on the Mac

Apple's rules on iOS are strict:

- There is **no fn-key equivalent** — apps can't listen for global keys.
- **Keyboard extensions are forbidden from using the microphone** (all app
  extensions are), and are memory-capped far below what Whisper needs.

So *every* dictation keyboard on iOS — including Wispr Flow itself — uses the
same bounce pattern, and WhisperKey does too:

1. In any app, switch to the **WhisperKey keyboard** (hold the 🌐 globe key)
   and tap **🎤 Dictate**
2. The WhisperKey **app opens and immediately starts listening** — speak,
   then tap **Done**
3. **Swipe back** to the app you were in (or tap the ‹ back link, top-left)
4. The keyboard **types your transcript** into the text field automatically
   (it's also on your clipboard as a backup)

## Building it

You need a Mac with Xcode 15+, plus [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(keyboard extensions need a real Xcode project, which XcodeGen generates):

```bash
brew install xcodegen
cd ios
xcodegen                       # generates WhisperKeyMobile.xcodeproj
open WhisperKeyMobile.xcodeproj
```

In Xcode:

1. Select the **WhisperKeyMobile** target → *Signing & Capabilities* → pick
   your **Team**. Do the same for the **WhisperKeyboard** target.
2. If signing complains the bundle id or App Group is unavailable, rename
   `com.whisperkey.ios` and `group.com.whisperkey.shared` in `project.yml`
   (and the group id in `Shared/SharedTranscript.swift`), rerun `xcodegen`.
3. Plug in your iPhone, select it as the destination, hit **Run**.

A free Apple ID works for your own phone (the app expires after 7 days and
needs a re-install from Xcode). For a no-hassle install on your dad's phone,
a paid Apple Developer account ($99/yr) + TestFlight is the practical route.

## One-time iPhone setup

1. Launch WhisperKey once — allow the microphone, let the model download
2. Settings → General → Keyboard → Keyboards → **Add New Keyboard…** → WhisperKey
3. Tap WhisperKey in that list → enable **Allow Full Access**
   (required so the keyboard can receive your transcript through the shared
   App Group — the keyboard itself has no microphone or network access)
4. In any app, hold the 🌐 key → WhisperKey → tap 🎤

The in-app **Setup** screen walks through the same steps.

## Zero-code alternative worth knowing

If the bounce flow feels like too much ceremony, two built-in options are
genuinely good:

- **Apple's built-in dictation** (🎤 key on the stock keyboard) is on-device
  and has the tightest integration iOS allows — Apple reserves that spot
  for itself.
- **Action Button + Shortcuts** (iPhone 15 Pro and later): create a Shortcut
  with *Dictate Text* → *Copy to Clipboard*, assign it to the Action Button,
  then paste anywhere.

WhisperKey's advantage over both is Whisper-quality accuracy, filler-word
cleanup, and everything staying on-device with an open-source app.
