//  SegmentRecorder.swift
//  NavCam2.0
//
//  Handles cyclic dash‑cam‑style recording: captures fixed‑length video clips and
//  prunes old files to respect a user‑defined storage cap.
//
//  Created by ChatGPT on 4/26/25.

import Foundation
import AVFoundation
import Combine

/// A lightweight dash‑cam recorder that uses a single `AVCaptureSession` and
/// rotates `AVCaptureMovieFileOutput` recordings every `clipLength` seconds.
/// Older files are deleted when the total size of stored clips exceeds
/// `maxStorageBytes`.
@MainActor
final class SegmentRecorder: NSObject, ObservableObject {
    // MARK: – Public, user‑tweakable settings (provide UI elsewhere)
    @Published var clipLength: TimeInterval      = 30        // seconds
    @Published var resolution: CGSize           = .init(width: 1280, height: 720) // 720p
    @Published var frameRate: Int               = 30         // fps
    @Published var maxStorageBytes: Int64       = 1_000_000_000 // 1 GB
    @Published private(set) var finishedClipURL: URL?

    // MARK: – Published state
    @Published var isRecording = false

    // MARK: – Private properties
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var clipTimer: AnyCancellable?
    private var currentOutputURL: URL?

    private var clipsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NavCamClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: – Public control API
    func toggle() { isRecording ? stop() : start() }

    func start() {
        guard !isRecording else { return }
        configureSessionIfNeeded()
        session.startRunning()
        isRecording = true
        startNewClip()
        scheduleTimer()
    }

    func stop() {
        guard isRecording else { return }
        clipTimer?.cancel()
        movieOutput.stopRecording()
        session.stopRunning()
        isRecording = false
    }

    // MARK: – Session setup (called once)
    private var sessionConfigured = false
    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720 // default; may be overridden later

        // Camera input – back wide‑angle preferred
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .back)
        guard let camera = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)

        // Configure desired frame rate
        if let format = camera.formats.first(where: { format in
            let desc = format.formatDescription
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            return dims.width == Int32(resolution.width) && dims.height == Int32(resolution.height)
        }) {
            try? camera.lockForConfiguration()
            camera.activeFormat = format
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            camera.activeVideoMaxFrameDuration = camera.activeVideoMinFrameDuration
            camera.unlockForConfiguration()
        }

        // Movie output
        guard session.canAddOutput(movieOutput) else { return }
        session.addOutput(movieOutput)
        movieOutput.maxRecordedDuration = CMTimeMakeWithSeconds(clipLength, preferredTimescale: 1)
        session.commitConfiguration()
        sessionConfigured = true
    }

    // MARK: – Clip rotation
    private func scheduleTimer() {
        clipTimer = Timer.publish(every: clipLength, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.startNewClip()
            }
    }

    private func startNewClip() {
        // Stop current clip
        if movieOutput.isRecording { movieOutput.stopRecording() }
        pruneIfNeeded()
        // Start new one
        let url = clipsDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        currentOutputURL = url
    }

    // MARK: – Storage management
    private func pruneIfNeeded() {
        let files = (try? FileManager.default.contentsOfDirectory(at: clipsDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        var sorted = files
        sorted.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        var totalSize: Int64 = files.reduce(0) { acc, url in (url.fileSize ?? 0) + acc }
        while totalSize > maxStorageBytes, let oldest = sorted.first {
            try? FileManager.default.removeItem(at: oldest)
            totalSize -= (oldest.fileSize ?? 0)
            sorted.removeFirst()
        }
    }
}

// MARK: – AVCaptureFileOutputRecordingDelegate
extension SegmentRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // prune again in case final file pushed us over the limit
        Task { @MainActor in
            pruneIfNeeded()
            finishedClipURL = outputFileURL
        }
    }
}

// MARK: – Helpers
private extension URL {
    var creationDate: Date? { (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate }
    var fileSize: Int64? { (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) }
}
