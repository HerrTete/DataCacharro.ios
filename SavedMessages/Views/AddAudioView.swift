import SwiftUI
import AVFoundation

struct AddAudioView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss

    enum RecordingState {
        case idle, recording, paused, stopped
    }

    @State private var state: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var permissionDenied = false
    @State private var setupError: String?

    // Playback
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackPosition: TimeInterval = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var playbackTimer: Timer?
    @State private var isSeeking = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Duration display
                Text(formatDuration(state == .stopped ? playbackDuration : recordingDuration))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundStyle(state == .recording ? .red : (state == .paused ? .orange : .primary))

                // Icon
                iconView

                // Recording controls
                if state == .idle || state == .recording || state == .paused {
                    recordingControls
                }

                // Playback controls (after recording)
                if state == .stopped {
                    playbackControls
                }

                Spacer()

                if permissionDenied {
                    Text("Microphone access denied. Please enable it in Settings.")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                if let error = setupError {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Audio Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cleanUp()
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecording()
                        dismiss()
                    }
                    .disabled(state != .stopped)
                    .accessibilityIdentifier("saveButton")
                }
            }
        }
        .onAppear {
            LocationService.shared.start()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .idle:
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundStyle(.purple)
        case .recording:
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .symbolEffect(.variableColor.iterative, isActive: true)
        case .paused:
            Image(systemName: "waveform.badge.minus")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
        case .stopped:
            Image(systemName: "waveform.badge.checkmark")
                .font(.system(size: 80))
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var recordingControls: some View {
        HStack(spacing: 32) {
            if state == .recording || state == .paused {
                // Pause / Resume button
                Button {
                    if state == .recording {
                        pauseRecording()
                    } else {
                        resumeRecording()
                    }
                } label: {
                    Label(
                        state == .recording ? "Pause" : "Resume",
                        systemImage: state == .recording ? "pause.circle.fill" : "record.circle"
                    )
                    .font(.title2)
                    .padding()
                    .background(state == .recording ? Color.orange.opacity(0.15) : Color.red.opacity(0.15))
                    .foregroundStyle(state == .recording ? .orange : .red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("pauseResumeButton")

                // Stop button
                Button {
                    stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("stopButton")
            } else {
                // Record button (idle state)
                Button {
                    startRecording()
                } label: {
                    Label("Record", systemImage: "record.circle")
                        .font(.title2)
                        .padding()
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("recordButton")
            }
        }
    }

    @ViewBuilder
    private var playbackControls: some View {
        VStack(spacing: 16) {
            // Timeline slider
            VStack(spacing: 4) {
                Slider(
                    value: $playbackPosition,
                    in: 0...max(playbackDuration, 0.01),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            player?.currentTime = playbackPosition
                            if isPlaying {
                                player?.play()
                            }
                        } else {
                            if isPlaying {
                                player?.pause()
                            }
                        }
                    }
                )
                .accessibilityIdentifier("playbackSlider")
                .tint(.purple)

                HStack {
                    Text(formatDuration(playbackPosition))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(playbackDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Playback buttons
            HStack(spacing: 32) {
                // Play / Pause
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.purple)
                }
                .accessibilityIdentifier("playPauseButton")
            }

            // Re-record button
            Button {
                stopPlayback()
                startRecording()
            } label: {
                Label("Re-record", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.10))
                    .foregroundStyle(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("reRecordButton")
        }
    }

    // MARK: - Recording

    private func startRecording() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    self.beginRecording()
                } else {
                    self.permissionDenied = true
                }
            }
        }
    }

    private func beginRecording() {
        stopPlayback()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            setupError = "Could not configure audio session: \(error.localizedDescription)"
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Remove previous recording file if re-recording
        if let oldURL = recordingURL {
            try? FileManager.default.removeItem(at: oldURL)
        }

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            recorder = rec
            recordingURL = url
            rec.record()
        } catch {
            setupError = "Could not start recording: \(error.localizedDescription)"
            return
        }
        setupError = nil
        state = .recording
        recordingDuration = 0

        startRecordingTimer()
    }

    private func pauseRecording() {
        recorder?.pause()
        timer?.invalidate()
        timer = nil
        state = .paused
    }

    private func resumeRecording() {
        recorder?.record()
        state = .recording
        startRecordingTimer()
    }

    private func stopRecording() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        state = .stopped
        preparePlayback()
    }

    private func startRecordingTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    // MARK: - Playback

    private func preparePlayback() {
        guard let url = recordingURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            playbackDuration = p.duration
            playbackPosition = 0
        } catch {
            setupError = "Could not prepare playback: \(error.localizedDescription)"
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            playbackTimer?.invalidate()
            playbackTimer = nil
            isPlaying = false
        } else {
            // Restart from beginning if at end
            if player.currentTime >= player.duration - 0.1 {
                player.currentTime = 0
                playbackPosition = 0
            }
            player.play()
            isPlaying = true
            startPlaybackTimer()
        }
    }

    private func stopPlayback() {
        player?.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        player = nil
        isPlaying = false
        playbackPosition = 0
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let player, !isSeeking else { return }
            playbackPosition = player.currentTime
            if !player.isPlaying && isPlaying {
                // Playback finished
                isPlaying = false
                playbackPosition = playbackDuration
                playbackTimer?.invalidate()
                playbackTimer = nil
            }
        }
    }

    // MARK: - Save / Cleanup

    private func saveRecording() {
        stopPlayback()
        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else { return }
        let name = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        storage.addFileItem(data: data, fileName: name, mimeType: "audio/mp4",
                            location: LocationService.shared.currentAddress)
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanUp() {
        stopPlayback()
        recorder?.stop()
        timer?.invalidate()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int(duration * 10) % 10
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
