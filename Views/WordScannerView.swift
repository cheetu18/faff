//
//  WordScannerView.swift
//  faff
//
//  Live camera word scanner. Vision recognizes text on the camera feed and a
//  reticle automatically snaps to (and resizes around) the word nearest a
//  target point. The target starts at screen-center and can be dragged onto
//  any other visible word. Tapping "Use Word" confirms the highlighted word.
//

import SwiftUI
import AVFoundation
import Vision

// MARK: - SwiftUI entry point

/// Whether the reticle snaps to a single word or to a whole line of text.
enum ScanMode {
    case word    // snap to one word, confirm a single term
    case phrase  // snap to a line, accumulate multiple lines for context
}

struct WordScannerView: View {
    var theme: AppTheme = ColorPack.rubberDucky.theme
    var mode: ScanMode = .word
    /// Called with the chosen word (.word) or accumulated text (.phrase).
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var candidate: String?
    @State private var buffer = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch authorization {
            case .authorized:
                cameraExperience
            case .notDetermined:
                ProgressView()
                    .tint(.white)
                    .task { await requestAccess() }
            default:
                deniedView
            }
        }
        .preferredColorScheme(.dark)
    }

    private var cameraExperience: some View {
        ZStack {
            ScannerRepresentable(highlightColor: theme.accent,
                                 lineMode: mode == .phrase,
                                 candidate: $candidate)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                switch mode {
                case .word:   wordFooter
                case .phrase: phraseFooter
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
        }
        .padding()
    }

    private var wordFooter: some View {
        VStack(spacing: 16) {
            hint("Drag to aim at a word")

            primaryButton(
                title: candidate.map { "Use \u{201C}\($0)\u{201D}" } ?? "Aim at a word",
                systemImage: "text.viewfinder",
                enabled: candidate != nil
            ) {
                if let candidate, !candidate.isEmpty {
                    onSelect(candidate)
                    dismiss()
                }
            }
        }
        .padding(.bottom, 24)
    }

    private var phraseFooter: some View {
        VStack(spacing: 14) {
            hint("Aim at a line, then add it to your context")

            if !buffer.isEmpty {
                ScrollView {
                    Text(buffer)
                        .font(.callout)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 110)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button {
                    if let candidate, !candidate.isEmpty {
                        buffer += (buffer.isEmpty ? "" : " ") + candidate
                    }
                } label: {
                    Label("Add line", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(candidate == nil ? Color.gray : Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(candidate == nil)

                Button {
                    onSelect(buffer)
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.headline)
                        .foregroundColor(theme.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(buffer.isEmpty ? Color.gray : theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(buffer.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func primaryButton(title: String,
                               systemImage: String,
                               enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title).lineLimit(1)
            }
            .font(.headline)
            .foregroundColor(theme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(enabled ? theme.primary : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!enabled)
        .padding(.horizontal)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.8))
            Text("Camera access needed")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text("Enable camera access in Settings to scan words.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)

            Button("Cancel") { dismiss() }
                .tint(.white)
        }
    }

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorization = granted ? .authorized : .denied
    }
}

// MARK: - UIViewControllerRepresentable bridge

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let highlightColor: Color
    let lineMode: Bool
    @Binding var candidate: String?

    func makeUIViewController(context: Context) -> CameraTextScannerController {
        let controller = CameraTextScannerController()
        controller.highlightColor = UIColor(highlightColor)
        controller.lineMode = lineMode
        controller.onCandidate = { word in
            // Marshalled to main by the controller already.
            if candidate != word { candidate = word }
        }
        return controller
    }

    func updateUIViewController(_ controller: CameraTextScannerController, context: Context) {
        controller.highlightColor = UIColor(highlightColor)
        controller.lineMode = lineMode
    }
}

// MARK: - Camera + Vision controller

final class CameraTextScannerController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var onCandidate: ((String?) -> Void)?
    var lineMode = false
    var highlightColor: UIColor = .systemYellow {
        didSet { highlightLayer.strokeColor = highlightColor.cgColor }
    }

    private let selectionFeedback = UISelectionFeedbackGenerator()

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "faff.scanner.session")
    private let videoQueue = DispatchQueue(label: "faff.scanner.video")

    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let highlightLayer = CAShapeLayer()

    private let defaultReticleSize = CGSize(width: 150, height: 52)
    private var targetPoint: CGPoint = .zero
    private var userMovedTarget = false

    private var isProcessing = false
    private var lastProcessTime = Date.distantPast
    private var lastObservations: [VNRecognizedTextObservation] = []
    private var reportedWord: String?

    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        return request
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        highlightLayer.fillColor = UIColor.clear.cgColor
        highlightLayer.strokeColor = highlightColor.cgColor
        highlightLayer.lineWidth = 3
        highlightLayer.cornerRadius = 10
        view.layer.addSublayer(highlightLayer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)

        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        if !userMovedTarget {
            targetPoint = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectionFeedback.prepare()
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: Session setup

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            // Keep analyzed frames upright in portrait so Vision boxes line up
            // with the preview.
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    // MARK: Frame processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Throttle to keep things smooth.
        let now = Date()
        guard !isProcessing, now.timeIntervalSince(lastProcessTime) > 0.18 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true
        lastProcessTime = now

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([textRequest])
            let observations = (textRequest.results as? [VNRecognizedTextObservation]) ?? []
            DispatchQueue.main.async { [weak self] in
                self?.lastObservations = observations
                self?.updateHighlight()
                self?.isProcessing = false
            }
        } catch {
            DispatchQueue.main.async { [weak self] in self?.isProcessing = false }
        }
    }

    // MARK: Highlight / selection

    private func updateHighlight() {
        guard previewLayer != nil else { return }
        let target = userMovedTarget ? targetPoint
                                     : CGPoint(x: view.bounds.midX, y: view.bounds.midY)

        var best: (word: String, rect: CGRect)?
        var bestScore = CGFloat.greatestFiniteMagnitude

        for observation in lastObservations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string

            // In phrase mode the reticle snaps to the whole line; in word mode
            // it snaps to each individual word.
            let segments: [(String, CGRect)]
            if lineMode {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                segments = trimmed.isEmpty ? [] : [(trimmed, observation.boundingBox)]
            } else {
                segments = text.wordRanges.compactMap { range in
                    guard
                        let box = try? candidate.boundingBox(for: range),
                        !box.boundingBox.isNull
                    else { return nil }
                    return (cleanWord(String(text[range])), box.boundingBox)
                }
            }

            for (string, normalized) in segments {
                let rect = layerRect(for: normalized)
                guard rect.width > 1, rect.height > 1, !string.isEmpty else { continue }

                // Prefer a segment the target sits inside; otherwise the closest.
                let contains = rect.contains(target)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let distance = hypot(center.x - target.x, center.y - target.y)
                let score = contains ? -1 : distance

                if score < bestScore {
                    bestScore = score
                    best = (string, rect)
                }
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let best, !best.word.isEmpty {
            highlightLayer.lineDashPattern = nil
            highlightLayer.path = UIBezierPath(
                roundedRect: best.rect.insetBy(dx: -6, dy: -6),
                cornerRadius: 10
            ).cgPath
            if reportedWord != best.word {
                reportedWord = best.word
                selectionFeedback.selectionChanged()
                selectionFeedback.prepare()
                onCandidate?(best.word)
            }
        } else {
            // No word nearby: show a dashed guide box at the target.
            highlightLayer.lineDashPattern = [6, 5]
            let guideRect = CGRect(
                x: target.x - defaultReticleSize.width / 2,
                y: target.y - defaultReticleSize.height / 2,
                width: defaultReticleSize.width,
                height: defaultReticleSize.height
            )
            highlightLayer.path = UIBezierPath(roundedRect: guideRect, cornerRadius: 10).cgPath
            if reportedWord != nil {
                reportedWord = nil
                onCandidate?(nil)
            }
        }

        CATransaction.commit()
    }

    /// Convert a Vision normalized bounding box (origin bottom-left) to a rect
    /// in the preview layer's coordinate space, honoring aspect-fill cropping.
    private func layerRect(for normalized: CGRect) -> CGRect {
        let metadataRect = CGRect(
            x: normalized.minX,
            y: 1 - normalized.maxY,
            width: normalized.width,
            height: normalized.height
        )
        return previewLayer.layerRectConverted(fromMetadataOutputRect: metadataRect)
    }

    private func cleanWord(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters))
    }

    // MARK: Gestures

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: view)
        userMovedTarget = true
        targetPoint = location
        updateHighlight()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        userMovedTarget = true
        targetPoint = location
        updateHighlight()
    }

    // MARK: Word range helper

}

private extension String {
    /// Ranges of whitespace-delimited words, preserving indices for Vision's
    /// `boundingBox(for:)`.
    var wordRanges: [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var idx = startIndex
        while idx < endIndex {
            while idx < endIndex, self[idx].isWhitespace { idx = index(after: idx) }
            guard idx < endIndex else { break }
            let start = idx
            while idx < endIndex, !self[idx].isWhitespace { idx = index(after: idx) }
            ranges.append(start..<idx)
        }
        return ranges
    }
}
