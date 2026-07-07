import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .loadingModel:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Downloading / loading the speech model…")
                            .foregroundStyle(.secondary)
                        Text("One-time download. Everything runs on your iPhone after this.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                case .ready:
                    ReadyView()
                case .recording:
                    RecordingView()
                case .transcribing:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Transcribing…").foregroundStyle(.secondary)
                    }
                case .finished(let text):
                    FinishedView(text: text)
                case .failed(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text(message)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") { model.reloadModel() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("WhisperKey")
            .toolbar {
                NavigationLink("Setup") { SetupView() }
            }
        }
    }
}

/// Idle state: big record button + a pointer to setup on first run.
private struct ReadyView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Button {
                model.startRecording()
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 44))
                    Text("Dictate")
                        .font(.headline)
                }
                .frame(width: 160, height: 160)
                .background(Circle().fill(Color.accentColor.gradient))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Text("Or tap the 🎤 button on the WhisperKey keyboard\nin any app — it brings you here automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()

            NavigationLink("First time? Set up the keyboard →") { SetupView() }
                .font(.callout)
                .padding(.bottom)
        }
    }
}

private struct RecordingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 180 + CGFloat(model.level) * 60,
                           height: 180 + CGFloat(model.level) * 60)
                    .animation(.linear(duration: 0.1), value: model.level)
                Circle()
                    .fill(Color.red.gradient)
                    .frame(width: 160, height: 160)
                Image(systemName: "waveform")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            Text("Listening… speak naturally")
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 16) {
                Button("Cancel", role: .cancel) { model.cancelRecording() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button {
                    model.stopAndTranscribe()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
        .onTapGesture { model.stopAndTranscribe() }
    }
}

private struct FinishedView: View {
    @EnvironmentObject private var model: AppModel
    let text: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            if model.launchedFromKeyboard {
                Text("Swipe back to your app")
                    .font(.title2.bold())
                Text("Use the ‹ back link in the top-left corner or swipe from the left edge. WhisperKey will type this for you:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Copied to clipboard")
                    .font(.title2.bold())
            }

            Text(text)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
                .padding(.horizontal)

            Text("(Also copied to your clipboard as a backup — long-press → Paste works anywhere.)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
            Button("Dictate again") { model.resetForNextDictation() }
                .buttonStyle(.bordered)
                .padding(.bottom)
        }
    }
}

/// One-time setup instructions + preferences.
private struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var modelID = Settings.shared.modelID
    @State private var removeFillers = Settings.shared.removeFillers

    var body: some View {
        List {
            Section("Enable the keyboard (one time)") {
                Label("Open Settings → General → Keyboard → Keyboards", systemImage: "1.circle")
                Label("Add New Keyboard… → WhisperKey", systemImage: "2.circle")
                Label("Tap WhisperKey → turn on Allow Full Access (lets the keyboard receive your transcript — it can't touch your mic or the network)", systemImage: "3.circle")
                Label("In any app: hold the 🌐 globe key → choose WhisperKey → tap 🎤", systemImage: "4.circle")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section("Speech model") {
                Picker("Model", selection: $modelID) {
                    ForEach(WhisperModel.all, id: \.id) { m in
                        Text("\(m.label) — \(m.detail)").tag(m.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: modelID) { _, newValue in
                    Settings.shared.modelID = newValue
                    model.reloadModel()
                }
                Text("Tiny or Base recommended on iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Cleanup") {
                Toggle("Remove filler words (um, uh)", isOn: $removeFillers)
                    .onChange(of: removeFillers) { _, newValue in
                        Settings.shared.removeFillers = newValue
                    }
            }

            Section("Privacy") {
                Text("Audio is recorded only while this screen is listening, transcribed on-device with Whisper, and discarded. Nothing ever leaves your iPhone except the one-time model download.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Setup")
    }
}
