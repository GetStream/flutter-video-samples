import Flutter
import UIKit
import stream_video_filters
import stream_webrtc_flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let CHANNEL = "io.getstream.video_livestream_overlay.channel"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: CHANNEL, binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call: call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerScoreboardEffect":
            ProcessorProvider.addProcessor(ScoreboardVideoFrameProcessor(), forName: "scoreboard")
            result(nil)
        case "updateScoreboardState":
            if let args = call.arguments as? [String: Any] {
                ScoreboardState.shared.update(args)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// Mutable snapshot of the scoreboard configuration, pushed from Flutter via
/// `updateScoreboardState`. The filter reads a consistent copy once per frame
/// via `snapshot()` so mid-update tearing is avoided. A monotonically
/// increasing `version` is bumped on every update and used as part of the
/// overlay cache key, so the next frame re-renders whenever the state changes
/// (and otherwise reuses the cached CIImage).
final class ScoreboardState {
    static let shared = ScoreboardState()

    struct Snapshot {
        var homeLabel: String
        var awayLabel: String
        var homeScore: String
        var awayScore: String
        var periodLabel: String
        var clockLabel: String
        var mirror: Bool
        var version: Int
    }

    private let lock = NSLock()
    private var current = Snapshot(
        homeLabel: "HOME",
        awayLabel: "AWAY",
        homeScore: "2",
        awayScore: "0",
        periodLabel: "P1",
        clockLabel: "20:00",
        mirror: false,
        version: 0
    )

    func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func update(_ args: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        if let v = args["homeLabel"] as? String { current.homeLabel = v }
        if let v = args["awayLabel"] as? String { current.awayLabel = v }
        if let v = args["homeScore"] as? String { current.homeScore = v }
        if let v = args["awayScore"] as? String { current.awayScore = v }
        if let v = args["periodLabel"] as? String { current.periodLabel = v }
        if let v = args["clockLabel"] as? String { current.clockLabel = v }
        if let v = args["mirror"] as? Bool { current.mirror = v }
        current.version &+= 1
    }
}

/// Scoreboard overlay filter. Runs on the local publisher track, so the
/// overlay is encoded into the outgoing WebRTC video and flows through to all
/// participants and HLS/RTMP egress.
///
/// Keeps `originalImage` in raw sensor coords, pre-orients the overlay with
/// `oriented(originalImageOrientation)` so its pixels align with the raw
/// pixel buffer, then composites in raw coords — same pattern as
/// `ImageBackgroundVideoFrameProcessor` in `stream_video_filters`.
///
/// Mirroring is driven by `ScoreboardState.mirror`, which Flutter flips on
/// based on the active camera / preview. When `true`, the drawing context is
/// pre-flipped so the local selfie-preview mirror cancels it out. When
/// `false`, nothing is flipped — correct for back-camera or non-mirrored
/// renderers.
///
/// Only one cached overlay lives at any time: (width, height, state version).
/// Updates bump the version and the next frame re-renders.
final class ScoreboardVideoFrameProcessor: stream_video_filters.VideoFilter {
    @available(*, unavailable)
    override public init(filter: @escaping (Input) -> CIImage) { fatalError() }

    private var cached: (key: String, image: CIImage)?
    private let cacheQueue = DispatchQueue(label: "io.getstream.video_livestream_overlay.scoreboard.cache")

    init() {
        super.init(filter: { input in input.originalImage })
        self.filter = { [weak self] input in
            guard let self = self else { return input.originalImage }

            let orientation = input.originalImageOrientation
            let rawExtent = input.originalImage.extent
            let isSideways =
                orientation == .left || orientation == .right
                || orientation == .leftMirrored || orientation == .rightMirrored
            let displayWidth = isSideways ? rawExtent.height : rawExtent.width
            let displayHeight = isSideways ? rawExtent.width : rawExtent.height

            let snapshot = ScoreboardState.shared.snapshot()
            let uprightOverlay = self.overlay(
                displayWidth: displayWidth, displayHeight: displayHeight, snapshot: snapshot
            )
            let alignedOverlay = uprightOverlay.oriented(orientation)

            return alignedOverlay
                .composited(over: input.originalImage)
                .cropped(to: input.originalImage.extent)
        }
    }

    private func overlay(
        displayWidth: CGFloat, displayHeight: CGFloat, snapshot: ScoreboardState.Snapshot
    ) -> CIImage {
        let key = "\(Int(displayWidth))x\(Int(displayHeight))-\(snapshot.version)"
        return cacheQueue.sync {
            if let cached = cached, cached.key == key {
                return cached.image
            }
            let uiImage = ScoreboardVideoFrameProcessor.renderScoreboard(
                width: displayWidth, height: displayHeight, snapshot: snapshot
            )
            let ciImage = CIImage(image: uiImage) ?? CIImage.empty()
            cached = (key: key, image: ciImage)
            return ciImage
        }
    }

    private static func renderScoreboard(
        width: CGFloat, height: CGFloat, snapshot: ScoreboardState.Snapshot
    ) -> UIImage {
        let shorter = min(width, height)
        let boardWidth = shorter * 0.72
        let boardHeight = shorter * 0.12
        let cornerRadius = boardHeight * 0.18
        let left = (width - boardWidth) / 2.0
        let top = shorter * 0.12
        let rect = CGRect(x: left, y: top, width: boardWidth, height: boardHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height), format: format
        )

        return renderer.image { ctx in
            let cg = ctx.cgContext

            if snapshot.mirror {
                cg.translateBy(x: width, y: 0)
                cg.scaleBy(x: -1, y: 1)
            }

            UIColor(white: 0.1, alpha: 0.9).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).fill()

            cg.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            let stripeWidth = boardWidth * 0.022
            UIColor(red: 0.898, green: 0.224, blue: 0.208, alpha: 1).setFill()  // home / red
            UIRectFill(CGRect(x: rect.minX, y: rect.minY, width: stripeWidth, height: rect.height))
            UIColor(red: 0.118, green: 0.533, blue: 0.898, alpha: 1).setFill()  // away / blue
            UIRectFill(
                CGRect(
                    x: rect.maxX - stripeWidth, y: rect.minY,
                    width: stripeWidth, height: rect.height
                )
            )
            cg.restoreGState()

            let labelFont = UIFont.systemFont(ofSize: boardHeight * 0.26, weight: .bold)
            let scoreFont = UIFont.systemFont(ofSize: boardHeight * 0.60, weight: .bold)
            let metaFont = UIFont.systemFont(ofSize: boardHeight * 0.16, weight: .regular)

            drawText(
                snapshot.homeLabel,
                at: CGPoint(x: rect.minX + boardWidth * 0.16, y: rect.midY),
                font: labelFont, color: .white
            )
            drawText(
                snapshot.awayLabel,
                at: CGPoint(x: rect.maxX - boardWidth * 0.16, y: rect.midY),
                font: labelFont, color: .white
            )
            drawText(
                snapshot.homeScore,
                at: CGPoint(x: rect.minX + boardWidth * 0.38, y: rect.midY),
                font: scoreFont, color: .white
            )
            drawText(
                snapshot.awayScore,
                at: CGPoint(x: rect.maxX - boardWidth * 0.38, y: rect.midY),
                font: scoreFont, color: .white
            )
            drawText(
                snapshot.periodLabel,
                at: CGPoint(x: rect.midX, y: rect.midY - boardHeight * 0.22),
                font: metaFont, color: UIColor(white: 0.74, alpha: 1)
            )
            drawText(
                snapshot.clockLabel,
                at: CGPoint(x: rect.midX, y: rect.midY + boardHeight * 0.22),
                font: metaFont, color: UIColor(white: 0.74, alpha: 1)
            )

            let divX1 = rect.midX - boardWidth * 0.065
            let divX2 = rect.midX + boardWidth * 0.065
            let divTop = rect.minY + boardHeight * 0.22
            let divBot = rect.maxY - boardHeight * 0.22
            let divider = UIBezierPath()
            divider.move(to: CGPoint(x: divX1, y: divTop))
            divider.addLine(to: CGPoint(x: divX1, y: divBot))
            divider.move(to: CGPoint(x: divX2, y: divTop))
            divider.addLine(to: CGPoint(x: divX2, y: divBot))
            divider.lineWidth = 1
            UIColor(white: 0.33, alpha: 1).setStroke()
            divider.stroke()
        }
    }

    private static func drawText(
        _ text: String, at center: CGPoint, font: UIFont, color: UIColor
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attrs)
    }
}
