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
    private var currentAsset: PHAsset?
    private var timeToSeek: CMTime?
    private var controlsView: MediaControlsView! // New controls view
    private let seekTolerance = CMTime(seconds: 0.1, preferredTimescale: 600)

    /// Tracks if this view is in full-screen presentation mode
    private var isFullScreen: Bool = false

    private let imageManager = PHCachingImageManager()

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
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }

    private func configureForVideo(asset: PHAsset, targetSize: CGSize) {
        controlsView.isHidden = false
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: imageOptions
        ) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }

        // Always setup video player (not just in full-screen)
        let videoOptions = PHVideoRequestOptions()
        videoOptions.isNetworkAccessAllowed = true
        videoOptions.deliveryMode = .highQualityFormat

        imageManager.requestAVAsset(forVideo: asset, options: videoOptions) { [weak self] avAsset, _, _ in
            guard let avAsset = avAsset else { return }
            DispatchQueue.main.async {
                self?.setupVideoPlayer(with: avAsset)

                // Non-fullscreen mode should auto-play
                if self?.isFullScreen == false {
                    self?.paused = false
                }
            }
        }
    }

    private func setupVideoPlayer(with avAsset: AVAsset) {
        cleanupPlayer()

        player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
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
            // Hide the thumbnail image when video is ready to play
            imageView.isHidden = true
        }

        // Enable looping by default
        setupVideoLooping()
    }

    private func setupVideoLooping() {
        guard let player = player else { return }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            player.seek(to: .zero)
            if !self.paused {
                player.play()
            }
        }
    }

    func snapshotImage() -> UIImage? {
        if let player, let item = player.currentItem {
            // Video
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.requestedTimeToleranceAfter = seekTolerance
            generator.requestedTimeToleranceBefore = seekTolerance
            generator.appliesPreferredTrackTransform = true

            guard let cgImage = try? generator.copyCGImage(at: item.currentTime(), actualTime: nil) else { return nil }

            let image = UIImage(cgImage: cgImage)
            return image
        } else {
            // Image
            return imageView.image
        }
    }

    private func cleanupPlayer() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)

        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil

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

    func syncVideoTime(with otherMediaView: MediaView) {
        guard let otherPlayer = otherMediaView.player,
              let player = self.player,
              otherPlayer.currentItem != nil else {
            // In case the current player is not ready, store the time to seek later
            timeToSeek = otherMediaView.player?.currentTime()
            return
        }

        let otherCurrentTime = otherPlayer.currentTime()
        // For faster sync you need to play around with the tolerance values, or use the same player instance between the synced views.
        player.seek(to: otherCurrentTime, toleranceBefore: .zero, toleranceAfter: seekTolerance)
    }

    static func createFullScreenMediaView(for asset: PHAsset, targetSize: CGSize) -> MediaView {
        let mediaView = MediaView()
        mediaView.configure(asset: asset, targetSize: targetSize, fullScreen: true)
        return mediaView
    }
}
