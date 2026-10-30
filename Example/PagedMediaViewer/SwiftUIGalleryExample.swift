//
//  SwiftUIGalleryExample.swift
//  PagedMediaViewer_Example
//
//  Created by Gorjan Shukov on 09/08/2026.
//

import SwiftUI
import Photos
import PagedMediaViewer

/// SwiftUI counterpart of `PagedMediaViewControllerExample`, presenting the viewer from a lazy grid.
@available(iOS 17.0, *)
struct SwiftUIGalleryView: View {
    struct PhotoItem: Identifiable {
        let asset: PHAsset

        var id: String { asset.localIdentifier }
        var isVideo: Bool { asset.mediaType == .video }
    }

    final class HeaderViews {
        weak var pageCountLabel: UILabel?
    }

    @State private var items: [PhotoItem] = []
    @State private var openedID: String?
    @State private var scrollID: String?
    @State private var headerViews = HeaderViews()
    @State private var videoStore = VideoThumbnailStore()

    private let spacing: CGFloat = 5
    private let horizontalInset: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = (proxy.size.width - horizontalInset * 2 - spacing) / 2
            let cellHeight = proxy.size.height * 0.45
            let cellSize = CGSize(width: cellWidth, height: cellHeight)

            ScrollView {
                LazyVGrid(columns: columns(width: cellWidth), spacing: spacing) {
                    ForEach(items) { item in
                        thumbnail(for: item, cellSize: cellSize)
                            .frame(width: cellWidth, height: cellHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { openedID = item.id }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalInset)
            }
            .scrollPosition(id: $scrollID, anchor: .center)
            .pagedMediaViewer(selection: $openedID,
                              items: items,
                              recenter: $scrollID,
                              configure: setupHeaderFooter,
                              onIndexChange: { index in
                                  headerViews.pageCountLabel?.text = "\(index + 1)/\(items.count)"
                              },
                              transitionImage: { item in videoStore.mediaView(for: item.id)?.snapshotImage() },
                              onWillDismiss: handOffPlayback,
                              onDidDismiss: resumePlayback,
                              mediaItem: { item in fullScreenMediaView(for: item, targetSize: proxy.size) })
        }
        .background(Color(uiColor: .systemBackground))
        .task { await loadAssets() }
    }

    @ViewBuilder
    private func thumbnail(for item: PhotoItem, cellSize: CGSize) -> some View {
        if item.isVideo {
            VideoThumbnail(mediaView: videoStore.mediaView(for: item.asset, targetSize: cellSize))
                .pagedMediaSource(id: item.id)
                .onAppear { videoStore.mediaView(for: item.id)?.paused = false }
                .onDisappear { videoStore.mediaView(for: item.id)?.paused = true }
        } else {
            PhotoThumbnail(asset: item.asset,
                           targetSize: CGSize(width: cellSize.width * 2, height: cellSize.height * 2))
        }
    }

    private func columns(width: CGFloat) -> [GridItem] {
        [GridItem(.fixed(width), spacing: spacing), GridItem(.fixed(width), spacing: spacing)]
    }

    // MARK: - Viewer

    private func fullScreenMediaView(for item: PhotoItem, targetSize: CGSize) -> MediaView {
        // Also keeps the transition snapshot on the same frame the media item starts from
        videoStore.pauseAll()

        let mediaView = MediaView.createFullScreenMediaView(for: item.asset, targetSize: targetSize)

        if let thumbnailView = videoStore.mediaView(for: item.id) {
            mediaView.syncVideoTime(with: thumbnailView, exact: true)
        }

        return mediaView
    }

    private func handOffPlayback(for item: PhotoItem, from mediaItem: PagedMediaItem) {
        guard
            let thumbnailView = videoStore.mediaView(for: item.id),
            let mediaView = mediaItem as? MediaView,
            thumbnailView.isAnimated
        else { return }

        // Hold the same frame as the dismissed item, playback resumes once the transition ends
        videoStore.resumesPlaybackAfterDismiss = !mediaItem.paused
        thumbnailView.paused = true
        thumbnailView.syncVideoTime(with: mediaView, exact: true)
    }

    private func resumePlayback(for item: PhotoItem) {
        videoStore.resumePaused(except: item.id)

        guard
            videoStore.resumesPlaybackAfterDismiss,
            let thumbnailView = videoStore.mediaView(for: item.id)
        else { return }

        videoStore.resumesPlaybackAfterDismiss = false
        thumbnailView.paused = false
    }

    // MARK: - Assets

    private func loadAssets() async {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }

        guard status == .authorized || status == .limited else { return }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)

        var fetched: [PhotoItem] = []
        result.enumerateObjects { asset, _, _ in fetched.append(PhotoItem(asset: asset)) }
        items = fetched

        MediaAssetLoader.shared.prefetchVideos(in: fetched.prefix(6).map(\.asset))
    }
}

// MARK: - Custom header and footer for PagedMediaViewController

@available(iOS 17.0, *)
private extension SwiftUIGalleryView {
    func setupHeaderFooter(for viewController: PagedMediaViewController) {
        let footerStackView = UIStackView()
        footerStackView.axis = .horizontal
        footerStackView.distribution = .equalCentering

        for imageName in ["externaldrive", "tray.and.arrow.down", "eraser", "highlighter", "ruler"] {
            let button = UIButton()
            button.tintColor = .white
            button.setImage(UIImage(systemName: imageName), for: .normal)
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            footerStackView.addArrangedSubview(button)
        }

        viewController.footerViewContainer.backgroundColor = .black.withAlphaComponent(0.5)
        viewController.footerViewContainer.addSubview(footerStackView)
        footerStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerStackView.leadingAnchor.constraint(equalTo: viewController.footerViewContainer.layoutMarginsGuide.leadingAnchor),
            footerStackView.topAnchor.constraint(equalTo: viewController.footerViewContainer.layoutMarginsGuide.topAnchor),
            footerStackView.trailingAnchor.constraint(equalTo: viewController.footerViewContainer.layoutMarginsGuide.trailingAnchor),
            footerStackView.bottomAnchor.constraint(equalTo: viewController.footerViewContainer.layoutMarginsGuide.bottomAnchor)
        ])

        let closeButton = UIButton(type: .system, primaryAction: UIAction { [weak viewController] _ in
            viewController?.dismiss(animated: true)
        })
        closeButton.accessibilityIdentifier = "closeButton"
        closeButton.tintColor = .white
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)

        let pageCountLabel = UILabel()
        pageCountLabel.textColor = .white
        pageCountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        pageCountLabel.text = "\(viewController.initialIndex + 1)/\(items.count)"
        headerViews.pageCountLabel = pageCountLabel

        viewController.headerViewContainer.backgroundColor = .black.withAlphaComponent(0.5)
        viewController.headerViewContainer.addSubview(closeButton)
        viewController.headerViewContainer.addSubview(pageCountLabel)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        pageCountLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: viewController.headerViewContainer.layoutMarginsGuide.leadingAnchor),
            closeButton.topAnchor.constraint(equalTo: viewController.headerViewContainer.layoutMarginsGuide.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: viewController.headerViewContainer.layoutMarginsGuide.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            pageCountLabel.centerXAnchor.constraint(equalTo: viewController.headerViewContainer.layoutMarginsGuide.centerXAnchor),
            pageCountLabel.centerYAnchor.constraint(equalTo: viewController.headerViewContainer.layoutMarginsGuide.centerYAnchor)
        ])
    }
}

// MARK: - Video thumbnails

@available(iOS 17.0, *)
@MainActor
final class VideoThumbnailStore {
    var resumesPlaybackAfterDismiss = false

    // Bounded, since every retained player holds on to a video decoder
    private let capacity = 8
    private var mediaViews: [String: MediaView] = [:]
    private var recentIDs: [String] = []
    private var pausedIDs: Set<String> = []

    func mediaView(for asset: PHAsset, targetSize: CGSize) -> MediaView {
        let id = asset.localIdentifier
        let mediaView = mediaViews[id] ?? makeMediaView(for: asset, targetSize: targetSize)
        mediaViews[id] = mediaView
        recentIDs.removeAll { $0 == id }
        recentIDs.append(id)

        while recentIDs.count > capacity {
            mediaViews[recentIDs.removeFirst()] = nil
        }

        return mediaView
    }

    func mediaView(for id: String) -> MediaView? {
        mediaViews[id]
    }

    func pauseAll() {
        for (id, mediaView) in mediaViews where !mediaView.paused {
            mediaView.paused = true
            pausedIDs.insert(id)
        }
    }

    func resumePaused(except excludedID: String) {
        for id in pausedIDs where id != excludedID {
            mediaViews[id]?.paused = false
        }

        pausedIDs.removeAll()
    }

    private func makeMediaView(for asset: PHAsset, targetSize: CGSize) -> MediaView {
        let mediaView = MediaView()
        mediaView.configure(asset: asset, targetSize: targetSize)
        // Thumbnails are passive, the cell opens the viewer where playback is controlled
        mediaView.isUserInteractionEnabled = false
        mediaView.animatedItemControlsView?.isHidden = true

        return mediaView
    }
}

@available(iOS 17.0, *)
struct VideoThumbnail: UIViewRepresentable {
    let mediaView: MediaView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        container.accessibilityIdentifier = "swiftUIVideoThumbnail"
        attach(to: container)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        attach(to: uiView)
    }

    private func attach(to container: UIView) {
        guard mediaView.superview !== container else { return }

        mediaView.removeFromSuperview()
        mediaView.frame = container.bounds
        mediaView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(mediaView)
    }
}

// MARK: - Photo thumbnails

@available(iOS 17.0, *)
struct PhotoThumbnail: View {
    let asset: PHAsset
    let targetSize: CGSize

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .pagedMediaSource(id: asset.localIdentifier)
            } else {
                Color(uiColor: .secondarySystemBackground)
                    .pagedMediaSource(id: asset.localIdentifier)
            }
        }
        .accessibilityIdentifier("swiftUIThumbnail")
        .onAppear {
            guard image == nil else { return }

            requestID = MediaAssetLoader.shared.requestImage(for: asset, targetSize: targetSize) { image in
                self.image = image
            }
        }
        .onDisappear {
            guard let requestID else { return }

            MediaAssetLoader.shared.cancelImageRequest(requestID)
            self.requestID = nil
        }
    }
}
