//
//  WordScannerView.swift
//  faff
//
//  Live camera word scanner. Vision recognizes text in a band around an aim
//  point and a reticle locks onto the word under it, staying put until the
//  aim point has clearly moved to another word. The aim point starts at
//  screen-center and can be tapped or dragged onto any other visible word.
//  Tapping "Use Word" confirms the highlighted word.
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

    /// False on hardware with no rear camera (e.g. a Mac running the iPhone
    /// app), where the capture session would otherwise show a black screen.
    private let hasCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back) != nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !hasCamera {
                unavailableView
            } else {
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
        }
        .preferredColorScheme(.dark)
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text("No camera available")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text("Scanning needs a rear camera. You can still add words by typing them.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 40)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
        }
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
            hint("Tap or drag to aim at a word")

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

// MARK: - Recognition results

/// One selectable piece of text: a word (word mode) or a line (phrase mode).
/// `box` is normalized to the upright camera image with a top-left origin.
private struct ScanSegment {
    let text: String
    let box: CGRect
}

private struct ScanFrame {
    /// Size of the upright camera image the boxes are normalized to.
    let imageSize: CGSize
    let segments: [ScanSegment]
}

// MARK: - Text recognizer

/// Runs Vision on camera frames. `recognize` is only called from the video
/// queue; the small `Config` the main thread adjusts (where to look, what to
/// return) is guarded by a lock.
private final class TextRecognizer: @unchecked Sendable {
    struct Config {
        /// Vision coordinates: normalized, bottom-left origin.
        var regionOfInterest = CGRect(x: 0, y: 0.35, width: 1, height: 0.3)
        var lineMode = false
        var orientation: CGImagePropertyOrientation = .up
    }

    private let lock = NSLock()
    private var config = Config()

    /// The accurate recognizer returns whole, language-corrected words with
    /// word-level boxes. (The fast one works character by character, which is
    /// what made the reticle hop between letters and word fragments.) Limiting
    /// it to a band around the aim point keeps it quick enough for live use.
    private let request: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        return request
    }()

    private var lastProcessTime = Date.distantPast

    func update(_ change: (inout Config) -> Void) {
        lock.lock()
        change(&config)
        lock.unlock()
    }

    /// Returns `nil` when the frame is skipped to stay under `minimumInterval`.
    func recognize(in pixelBuffer: CVPixelBuffer, minimumInterval: TimeInterval) -> ScanFrame? {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > minimumInterval else { return nil }
        lastProcessTime = now

        lock.lock()
        let config = self.config
        lock.unlock()

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imageSize = config.orientation == .up ? CGSize(width: width, height: height)
                                                  : CGSize(width: height, height: width)

        let roi = config.regionOfInterest
        request.regionOfInterest = roi
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: config.orientation,
                                            options: [:])
        guard (try? handler.perform([request])) != nil else {
            return ScanFrame(imageSize: imageSize, segments: [])
        }

        // Vision boxes are relative to the region of interest, bottom-left
        // origin. Convert to the full image, top-left origin.
        func imageBox(_ box: CGRect) -> CGRect {
            let w = box.width * roi.width
            let h = box.height * roi.height
            let x = roi.minX + box.minX * roi.width
            let y = roi.minY + box.minY * roi.height
            return CGRect(x: x, y: 1 - y - h, width: w, height: h)
        }

        var segments: [ScanSegment] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { continue }
            let text = candidate.string

            if config.lineMode {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(ScanSegment(text: trimmed, box: imageBox(observation.boundingBox)))
                }
                continue
            }

            for range in text.wordRanges {
                let word = String(text[range]).trimmingCharacters(in: Self.wordTrim)
                guard word.contains(where: \.isLetter),
                      let box = try? candidate.boundingBox(for: range),
                      !box.boundingBox.isNull else { continue }
                segments.append(ScanSegment(text: word, box: imageBox(box.boundingBox)))
            }
        }
        return ScanFrame(imageSize: imageSize, segments: segments)
    }

    private static let wordTrim = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(.symbols)
}

// MARK: - Camera + Vision controller

final class CameraTextScannerController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var onCandidate: ((String?) -> Void)?
    var lineMode = false {
        didSet {
            guard lineMode != oldValue else { return }
            let lineMode = lineMode
            recognizer.update { $0.lineMode = lineMode }
        }
    }
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

    // MARK: Selection state (main thread)

    private typealias Segment = (text: String, rect: CGRect)

    /// Latest recognized segments, in view coordinates.
    private var segments: [Segment] = []
    private var imageSize: CGSize = .zero

    /// The word the reticle is locked onto. It only changes once a different
    /// word has won for `switchThreshold` frames in a row, so hand shake and
    /// one-off OCR misreads don't move it.
    private var locked: Segment?
    private var pending: (text: String, count: Int)?
    private var missCount = 0
    private var reportedWord: String?

    private let switchThreshold = 2
    private let missThreshold = 4
    /// How far outside the locked word the aim point may drift before letting go.
    private let stickyMargin: CGFloat = 12
    /// How far from the aim point a word may be and still get picked up.
    private let snapRadius: CGFloat = 44
    /// Height of the band around the aim point that gets recognized.
    private let scanBandHeight: CGFloat = 200

    private let recognizer = TextRecognizer()

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
        view.layer.addSublayer(highlightLayer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleAim(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleAim(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)

        let lineMode = lineMode
        recognizer.update { $0.lineMode = lineMode }
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        if !userMovedTarget {
            targetPoint = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
        updateRegionOfInterest()
        render()
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
            // Book print is small; 720p doesn't leave enough pixels per letter.
            self.session.sessionPreset = self.session.canSetSessionPreset(.hd1920x1080)
                ? .hd1920x1080 : .hd1280x720

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

            // Deliver upright portrait frames when possible; otherwise tell
            // Vision the frames are rotated.
            var orientation = CGImagePropertyOrientation.right
            if let connection = self.videoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
                orientation = .up
            }
            self.recognizer.update { $0.orientation = orientation }

            self.session.commitConfiguration()
            self.configureForCloseUpText(device)
            self.session.startRunning()
        }
    }

    /// Keep a page held at reading distance sharp: favour near focus, and zoom
    /// in a little so the phone can sit beyond the lens's minimum focus
    /// distance while the text stays large.
    private func configureForCloseUpText(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        device.videoZoomFactor = min(1.5, device.activeFormat.videoMaxZoomFactor)
        device.unlockForConfiguration()
    }

    // MARK: Frame processing

    /// Called by AVFoundation on `videoQueue`.
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let frame = recognizer.recognize(in: pixelBuffer, minimumInterval: 0.1)
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.process(frame)
        }
    }

    private func process(_ frame: ScanFrame) {
        guard isViewLoaded else { return }
        if imageSize != frame.imageSize {
            imageSize = frame.imageSize
            updateRegionOfInterest()
        }
        segments = frame.segments.compactMap { segment in
            let rect = viewRect(forImageBox: segment.box)
            return rect.width > 1 && rect.height > 1 ? (segment.text, rect) : nil
        }
        updateSelection(immediate: false)
    }

    // MARK: Selection

    private var target: CGPoint {
        userMovedTarget ? targetPoint : CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    /// Decide which segment the reticle should be on.
    /// - Parameter immediate: `true` when the user just re-aimed, so the
    ///   reticle follows their finger without waiting for confirmation frames.
    private func updateSelection(immediate: Bool) {
        let target = self.target

        // Where the locked word is in this frame, if it's still visible.
        var continuation: Segment?
        if let locked {
            let reach = max(locked.rect.width, 60) * 1.5
            continuation = segments
                .filter { $0.text == locked.text && centerDistance($0.rect, locked.rect) < reach }
                .min { centerDistance($0.rect, locked.rect) < centerDistance($1.rect, locked.rect) }
        }

        // What the aim point is on (or nearest to) right now.
        let radius = lineMode ? snapRadius * 1.5 : snapRadius
        let hit = segments
            .map { (segment: $0, distance: distance(from: target, to: $0.rect)) }
            .filter { $0.distance <= radius }
            .min { $0.distance < $1.distance }?
            .segment

        // Hold on to the locked word while the aim point stays on or just
        // beside it, unless the aim point is clearly inside another word.
        var desired = hit
        if let continuation, distance(from: target, to: continuation.rect) <= stickyMargin {
            let clearlyOnAnother: Bool
            if let hit, hit.text != continuation.text || !hit.rect.intersects(continuation.rect) {
                let inset = min(3, hit.rect.height / 4)
                clearlyOnAnother = hit.rect.insetBy(dx: inset, dy: inset).contains(target)
            } else {
                clearlyOnAnother = false
            }
            if !clearlyOnAnother { desired = continuation }
        }

        guard let desired else {
            pending = nil
            missCount += 1
            if immediate || missCount >= missThreshold { locked = nil }
            render()
            return
        }
        missCount = 0

        if let current = locked, current.text == desired.text {
            // Same word: glide the box rather than snapping, to hide jitter.
            let smooth = !immediate && current.rect.intersects(desired.rect)
            locked = (current.text, smooth ? blend(current.rect, desired.rect, 0.6) : desired.rect)
            pending = nil
        } else {
            let count = (pending?.text == desired.text ? pending?.count ?? 0 : 0) + 1
            if immediate || locked == nil || count >= switchThreshold {
                locked = desired
                pending = nil
            } else {
                pending = (desired.text, count)
                if let continuation { locked = continuation }
            }
        }
        render()
    }

    private func render() {
        guard isViewLoaded else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let locked {
            highlightLayer.lineDashPattern = nil
            highlightLayer.path = UIBezierPath(
                roundedRect: locked.rect.insetBy(dx: -6, dy: -6),
                cornerRadius: 10
            ).cgPath
        } else {
            // Nothing under the aim point: show a dashed guide box there.
            let target = self.target
            highlightLayer.lineDashPattern = [6, 5]
            highlightLayer.path = UIBezierPath(
                roundedRect: CGRect(x: target.x - defaultReticleSize.width / 2,
                                    y: target.y - defaultReticleSize.height / 2,
                                    width: defaultReticleSize.width,
                                    height: defaultReticleSize.height),
                cornerRadius: 10
            ).cgPath
        }
        CATransaction.commit()

        if reportedWord != locked?.text {
            reportedWord = locked?.text
            if locked != nil {
                selectionFeedback.selectionChanged()
                selectionFeedback.prepare()
            }
            onCandidate?(locked?.text)
        }
    }

    // MARK: Geometry

    /// Scale and offset of the aspect-filled camera image inside the view.
    private var imageFit: (scale: CGFloat, offset: CGPoint)? {
        let bounds = view.bounds
        guard imageSize.width > 0, imageSize.height > 0, !bounds.isEmpty else { return nil }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return (scale, CGPoint(x: (bounds.width - imageSize.width * scale) / 2,
                               y: (bounds.height - imageSize.height * scale) / 2))
    }

    private func viewRect(forImageBox box: CGRect) -> CGRect {
        guard let fit = imageFit else { return .zero }
        return CGRect(x: box.minX * imageSize.width * fit.scale + fit.offset.x,
                      y: box.minY * imageSize.height * fit.scale + fit.offset.y,
                      width: box.width * imageSize.width * fit.scale,
                      height: box.height * imageSize.height * fit.scale)
    }

    /// Point Vision at a band of the image around the aim point.
    private func updateRegionOfInterest() {
        guard let fit = imageFit else { return }
        let target = self.target
        let band = CGRect(x: 0, y: target.y - scanBandHeight / 2,
                          width: view.bounds.width, height: scanBandHeight)
            .intersection(view.bounds)
        guard !band.isNull else { return }

        let w = imageSize.width * fit.scale
        let h = imageSize.height * fit.scale
        let top = (band.minY - fit.offset.y) / h
        let roi = CGRect(x: (band.minX - fit.offset.x) / w,
                         y: 1 - top - band.height / h,          // flip to bottom-left origin
                         width: band.width / w,
                         height: band.height / h)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !roi.isNull, roi.width > 0.05, roi.height > 0.02 else { return }
        recognizer.update { $0.regionOfInterest = roi }
    }

    /// Distance from a point to the nearest edge of a rect (0 when inside).
    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    private func centerDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        hypot(a.midX - b.midX, a.midY - b.midY)
    }

    private func blend(_ from: CGRect, _ to: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(x: from.minX + (to.minX - from.minX) * t,
               y: from.minY + (to.minY - from.minY) * t,
               width: from.width + (to.width - from.width) * t,
               height: from.height + (to.height - from.height) * t)
    }

    // MARK: Gestures

    /// Tap or drag moves the aim point.
    @objc private func handleAim(_ gesture: UIGestureRecognizer) {
        userMovedTarget = true
        targetPoint = gesture.location(in: view)
        updateRegionOfInterest()
        updateSelection(immediate: true)
    }
}

private extension String {
    /// Ranges of words, split on whitespace and long dashes, preserving
    /// indices for Vision's `boundingBox(for:)`.
    var wordRanges: [Range<String.Index>] {
        func isSeparator(_ c: Character) -> Bool {
            c.isWhitespace || c == "\u{2014}" || c == "\u{2013}"
        }
        var ranges: [Range<String.Index>] = []
        var idx = startIndex
        while idx < endIndex {
            while idx < endIndex, isSeparator(self[idx]) { idx = index(after: idx) }
            guard idx < endIndex else { break }
            let start = idx
            while idx < endIndex, !isSeparator(self[idx]) { idx = index(after: idx) }
            ranges.append(start..<idx)
        }
        return ranges
    }
}
