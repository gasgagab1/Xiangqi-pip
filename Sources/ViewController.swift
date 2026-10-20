import UIKit
import AVKit
import AVFoundation

final class ViewController: UIViewController,
    AVPictureInPictureControllerDelegate,
    AVPictureInPictureSampleBufferPlaybackDelegate {

    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController!
    private var timer: Timer?
    private var frameIndex: Int64 = 0

    // 这里换成你的AI输出
    private let tips = ["炮二平五", "马8进7", "车一平二", "兵七进一"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        displayLayer.frame = CGRect(x: 20, y: 80, width: 240, height: 135)
        displayLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(displayLayer)

        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        pipController = AVPictureInPictureController(contentSource: source)
        pipController.delegate = self

        let btn = UIButton(type: .system)
        btn.setTitle("开启悬浮窗", for: .normal)
        btn.frame = CGRect(x: 20, y: 240, width: 160, height: 44)
        btn.addTarget(self, action: #selector(startPiP), for: .touchUpInside)
        view.addSubview(btn)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.enqueueTip()
        }
        enqueueTip()
    }

    @objc private func startPiP() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController.startPictureInPicture()
        }
    }

    private func enqueueTip() {
        let text = tips[Int(frameIndex % Int64(tips.count))]
        frameIndex += 1

        let pts = CMTime(value: frameIndex, timescale: 1)
        guard let sample = makeSampleBuffer(
            text: text,
            size: CGSize(width: 480, height: 270),
            pts: pts
        ) else { return }

        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sample)
    }

    private func makeSampleBuffer(text: String, size: CGSize, pts: CMTime) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let pb = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        UIGraphicsPushContext(ctx)
        let ns = text as NSString
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 52),
            .foregroundColor: UIColor.green
        ]
        ns.draw(at: CGPoint(x: 24, y: 100), withAttributes: attr)
        UIGraphicsPopContext()

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pb,
            formatDescriptionOut: &format
        )
        guard let fmt = format else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 1),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pb,
            formatDescription: fmt,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        return sample
    }

    // MARK: - PiP Delegate
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {}

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        false
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("PiP启动失败:", error)
    }
}
