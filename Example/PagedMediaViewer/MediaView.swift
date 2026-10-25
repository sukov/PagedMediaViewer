//
//  MediaView.swift
//  PagedMediaViewer_Example
//
//  Created by Gorjan Shukov on 18.9.25.
//

import UIKit
import Photos
import AVFoundation
import PagedMediaViewer

class MediaControlsView: UIView {
    let playPauseButton: UIButton

    override init(frame: CGRect) {
        playPauseButton = UIButton(type: .system)
        super.init(frame: frame)

        playPauseButton.tintColor = .white
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(playPauseButton)

        NSLayoutConstraint.activate([
            playPauseButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            playPauseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playPauseButton.heightAnchor.constraint(equalToConstant: 60),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        // Disable touch handling on empty areas so media view double-tap zoom works correctly
        return hitView === self ? nil : hitView
    }
}

/// Example MediaView that supports both images and videos from the Photo Library.
class MediaView: UIView, PagedMediaItem {
    let imageView: UIImageView
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var videoOrientation: UIImage.Orientation = .up
    private var loopObserver: NSObjectProtocol?
    private var currentAsset: PHAsset?
    private var timeToSeek: CMTime?
    private var controlsView: MediaControlsView! // New controls view
    private let seekTolerance = CMTime(seconds: 0.1, preferredTimescale: 600)

    /// Tracks if this view is in full-screen presentation mode
    private var isFullScreen: Bool = false

    private var imageRequestID: PHImageRequestID?
    private var readyObservation: NSKeyValueObservation?

    // MARK: - PagedMediaItem Properties
    var paused: Bool = true {
        didSet {
            updatePlayPauseState()
        }
    }

    var isAnimated: Bool {
        currentAsset?.mediaType == .video
    }

    var animatedItemSnapshotAtCurrentTime: UIImage? {
        snapshotImage()
    }

    var animatedItemControlsView: UIView? {
        isAnimated ? controlsView : nil
    }

    override init(frame: CGRect) {
        imageView = UIImageView(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        super.init(frame: frame)

        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        controlsView = MediaControlsView()
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlsView)

        NSLayoutConstraint.activate([
            controlsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            controlsView.bottomAnchor.constraint(equalTo: bottomAnchor),
            controlsView.topAnchor.constraint(equalTo: topAnchor),
            controlsView.heightAnchor.constraint(equalTo: heightAnchor)
        ])

        controlsView.playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
    }

    @objc private func togglePlayPause() {
        paused.toggle()
    }

    private func updatePlayPauseState() {
        if paused {
            pauseVideo()
            controlsView.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            playVideo()
            controlsView.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

    /// Configures the MediaView with a PHAsset.
    /// - Parameters:
    ///   - asset: The PHAsset to display.
    ///   - targetSize: The size for image or thumbnail fetching.
    ///   - fullScreen: Whether the view is displayed in full-screen mode.
    func configure(asset: PHAsset, targetSize: CGSize, fullScreen: Bool = false) {
        currentAsset = asset
        isFullScreen = fullScreen

        // Cancel the previous image request
        if let imageRequestID {
            MediaAssetLoader.shared.cancelImageRequest(imageRequestID)
            self.imageRequestID = nil
        }

        // Clean up any existing video player
        cleanupPlayer()

        // Reset image
        imageView.image = nil

        if asset.mediaType == .image {
            configureForImage(asset: asset, targetSize: targetSize)
        } else if asset.mediaType == .video {
            configureForVideo(asset: asset, targetSize: targetSize)
        }
    }

    private func configureForImage(asset: PHAsset, targetSize: CGSize) {
        controlsView.isHidden = true
        requestPosterImage(for: asset, targetSize: targetSize)
    }

    private func requestPosterImage(for asset: PHAsset, targetSize: CGSize) {
        imageRequestID = MediaAssetLoader.shared.requestImage(for: asset, targetSize: targetSize) { [weak self] image in
            guard let self, self.currentAsset?.localIdentifier == asset.localIdentifier else { return }

            self.imageView.image = image
        }
    }

    private func configureForVideo(asset: PHAsset, targetSize: CGSize) {
        controlsView.isHidden = false
        requestPosterImage(for: asset, targetSize: targetSize)

        // Always setup video player (not just in full-screen)
        MediaAssetLoader.shared.loadAVAsset(for: asset) { [weak self] avAsset in
            guard
                let self,
                let avAsset,
                self.currentAsset?.localIdentifier == asset.localIdentifier
            else { return }

            self.setupVideoPlayer(with: avAsset)

            // Non-fullscreen mode should auto-play
            if !self.isFullScreen {
                self.paused = false
            }
        }
    }

    private func setupVideoPlayer(with avAsset: AVAsset) {
        cleanupPlayer()

        let playerItem = AVPlayerItem(asset: avAsset)
        let track = avAsset.tracks(withMediaType: .video).first
        videoOrientation = Self.orientation(of: track?.preferredTransform)

        // Provides the already decoded frames for snapshots
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: Self.outputAttributes(for: track?.naturalSize ?? .zero,
                                                                                          orientation: videoOrientation))
        playerItem.add(output)
        videoOutput = output

        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = true

        if let timeToSeek = timeToSeek {
            // Seek to the stored time if available
            player?.seek(to: timeToSeek, toleranceBefore: .zero, toleranceAfter: seekTolerance)
            self.timeToSeek = nil // Clear after seeking
        }

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = bounds

        if let playerLayer = playerLayer {
            layer.addSublayer(playerLayer)

            // Hide the thumbnail image once the first video frame is ready
            readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                guard layer.isReadyForDisplay else { return }

                DispatchQueue.main.async {
                    self?.imageView.isHidden = true
                    self?.readyObservation = nil
                }
            }
        }

        // Enable looping by default
        setupVideoLooping()
    }

    private func setupVideoLooping() {
        guard let player = player else { return }

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self, let player = self.player else { return }

            player.seek(to: .zero)

            if !self.paused {
                player.play()
            }
        }
    }

    func snapshotImage() -> UIImage? {
        guard let item = player?.currentItem else {
            // Image
            return imageView.image
        }

        // Already decoded frame, avoids a seek and decode on the main thread
        if let pixelBuffer = videoOutput?.copyPixelBuffer(forItemTime: item.currentTime(), itemTimeForDisplay: nil),
           let image = UIImage(pixelBuffer: pixelBuffer, orientation: videoOrientation) {
            return image
        }

        // Video
        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.requestedTimeToleranceAfter = seekTolerance
        generator.requestedTimeToleranceBefore = seekTolerance
        generator.appliesPreferredTrackTransform = true

        guard let cgImage = try? generator.copyCGImage(at: item.currentTime(), actualTime: nil) else { return nil }

        let image = UIImage(cgImage: cgImage)
        return image
    }

    private static func orientation(of transform: CGAffineTransform?) -> UIImage.Orientation {
        guard let transform else { return .up }

        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0):
            return .right
        case (0, -1, 1, 0):
            return .left
        case (-1, 0, 0, -1):
            return .down
        default:
            return .up
        }
    }

    /// Output frames scaled down to at most the screen size, since snapshots are never shown larger.
    private static func outputAttributes(for naturalSize: CGSize, orientation: UIImage.Orientation) -> [String: Any] {
        var attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

        guard naturalSize.width > 0, naturalSize.height > 0 else { return attributes }

        let scale = UIScreen.main.scale
        let screenSize = UIScreen.main.bounds.size
        // Frames are delivered in their encoded orientation
        let isRotated = orientation == .left || orientation == .right
        let bounds = CGSize(width: (isRotated ? screenSize.height : screenSize.width) * scale,
                            height: (isRotated ? screenSize.width : screenSize.height) * scale)
        let ratio = min(1, bounds.width / naturalSize.width, bounds.height / naturalSize.height)

        attributes[kCVPixelBufferWidthKey as String] = Int((naturalSize.width * ratio).rounded())
        attributes[kCVPixelBufferHeightKey as String] = Int((naturalSize.height * ratio).rounded())

        return attributes
    }

    /// Releases the video player and shows the thumbnail image. Configure the view again to reload it.
    func unloadVideo() {
        cleanupPlayer()
    }

    private func cleanupPlayer() {
        // Block based observers are only removed by their token
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
            self.loopObserver = nil
        }

        readyObservation = nil

        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
        videoOutput = nil

        // Show the thumbnail image again
        imageView.isHidden = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Disable implicit animations during frame update
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer?.frame = bounds
        CATransaction.commit()
    }

    func playVideo() {
        player?.play()
    }

    func pauseVideo() {
        player?.pause()
    }

    // MARK: - Video Synchronization Methods

    /// Seeks to the other view's current time. Pass `exact` for a frame accurate seek, e.g. when handing over playback.
    func syncVideoTime(with otherMediaView: MediaView, exact: Bool = false) {
        guard let otherPlayer = otherMediaView.player,
              let player = self.player,
              otherPlayer.currentItem != nil else {
            // In case the current player is not ready, store the time to seek later
            timeToSeek = otherMediaView.player?.currentTime()
            return
        }

        let otherCurrentTime = otherPlayer.currentTime()
        // For faster sync you need to play around with the tolerance values, or use the same player instance between the synced views.
        player.seek(to: otherCurrentTime, toleranceBefore: .zero, toleranceAfter: exact ? .zero : seekTolerance)
    }

    static func createFullScreenMediaView(for asset: PHAsset, targetSize: CGSize) -> MediaView {
        let mediaView = MediaView()
        mediaView.configure(asset: asset, targetSize: targetSize, fullScreen: true)
        return mediaView
    }
}

private extension UIImage {
    /// Wraps a BGRA pixel buffer without copying it. The buffer stays locked and retained for the image's lifetime.
    convenience init?(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }

        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let retainedBuffer = Unmanaged.passRetained(pixelBuffer)
        let provider = CGDataProvider(dataInfo: retainedBuffer.toOpaque(), data: baseAddress, size: bytesPerRow * height) { info, _, _ in
            guard let info else { return }

            let buffer = Unmanaged<CVPixelBuffer>.fromOpaque(info).takeRetainedValue()
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }

        guard let provider else {
            retainedBuffer.release()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let cgImage = CGImage(width: CVPixelBufferGetWidth(pixelBuffer),
                                    height: height,
                                    bitsPerComponent: 8,
                                    bitsPerPixel: 32,
                                    bytesPerRow: bytesPerRow,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: bitmapInfo,
                                    provider: provider,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: .defaultIntent)
        else { return nil }

        self.init(cgImage: cgImage, scale: 1, orientation: orientation)
    }
}
