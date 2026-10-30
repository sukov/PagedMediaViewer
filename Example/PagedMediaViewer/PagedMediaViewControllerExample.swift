//
//  PagedMediaViewControllerExample.swift
//  PagedMediaViewer_Example
//
//  Created by Gorjan Shukov on 16.9.25.
//

import UIKit
import SwiftUI
import Photos
import PagedMediaViewer

class PagedMediaViewControllerExample: UICollectionViewController, UICollectionViewDataSourcePrefetching {
    var fetchResult: PHFetchResult<PHAsset>
    var assetSize: CGSize = CGSize.zero
    private weak var pageCountLabel: UILabel?
    private var resumesPlaybackAfterDismiss = false
    private var pausedForViewer: [MediaView] = []

    private let cellReuseID = String(describing: PagedMediaCell.self)

    private var flowLayout: UICollectionViewFlowLayout {
        return collectionViewLayout as! UICollectionViewFlowLayout
    }

    // MARK: Initializers

    init() {
        self.fetchResult = PHFetchResult<PHAsset>()

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 1
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width * 0.45, height: UIScreen.main.bounds.height * 0.45)

        super.init(collectionViewLayout: layout)

        title = "All Photos"

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            DispatchQueue.main.async {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                self.fetchResult = PHAsset.fetchAssets(with: options)
                self.collectionView.reloadData()
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: ViewController Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.white
        view.clipsToBounds = true

        guard let collectionView else { return }

        collectionView.register(PagedMediaCell.self, forCellWithReuseIdentifier: cellReuseID)
        collectionView.isPrefetchingEnabled = true
        collectionView.prefetchDataSource = self
        collectionView.backgroundColor = .clear

        // Matches the size cells request, otherwise prefetched images are never hit
        assetSize = flowLayout.itemSize

        setupSwiftUIExampleButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Reload the players released while another screen covered the grid
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Covered by a pushed screen, the players would keep decoding and holding memory
        collectionView.visibleCells.forEach { ($0 as? PagedMediaCell)?.mediaView.unloadVideo() }
    }

    private func setupSwiftUIExampleButton() {
        guard #available(iOS 17.0, *) else { return }

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "SwiftUI", primaryAction: UIAction { [weak self] _ in
            let hostingController = UIHostingController(rootView: SwiftUIGalleryView())
            hostingController.title = "SwiftUI Grid"
            self?.navigationController?.pushViewController(hostingController, animated: true)
        })
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "swiftUIExampleButton"
    }

    // MARK: UICollectionViewDataSource

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        fetchResult.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseID, for: indexPath) as! PagedMediaCell

        let asset = fetchResult.object(at: indexPath.item)
        cell.configure(with: asset)

        return cell
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = PagedMediaViewController(initialIndex: indexPath.item)
        vc.pagedMediaDataSource = self
        vc.pagedMediaDelegate = self
        vc.view.accessibilityIdentifier = "pagedMediaViewController" // for UI tests
        vc.view.backgroundColor = .black
        setupFooterHeader(for: vc)
        present(vc, animated: true)
    }

    // MARK: UICollectionViewDataSourcePrefetching
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.map { fetchResult.object(at: $0.item) }

        MediaAssetLoader.shared.startCachingImages(for: assets, targetSize: assetSize)
        MediaAssetLoader.shared.prefetchVideos(in: assets)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.map { fetchResult.object(at: $0.item) }

        MediaAssetLoader.shared.stopCachingImages(for: assets, targetSize: assetSize)
    }
}

// MARK: PagedMediaDataSource
extension PagedMediaViewControllerExample: PagedMediaDataSource {
    func numberOfItems(in pagedMediaViewController: PagedMediaViewController) -> Int {
        fetchResult.count
    }
    
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, pagedMediaViewForItemAt index: Int) -> PagedMediaItem {
        pauseVideosCoveredByViewer()

        let asset = fetchResult.object(at: index)
        let mediaView = MediaView.createFullScreenMediaView(for: asset, targetSize: view.bounds.size)
        let cell = visibleCell(at: index)
        mediaView.syncVideoTime(with: cell.mediaView, exact: true)

        return mediaView
    }

    // Also keeps the transition snapshot on the same frame the media item starts from
    private func pauseVideosCoveredByViewer() {
        for cell in collectionView.visibleCells.compactMap({ $0 as? PagedMediaCell }) where !cell.mediaView.paused {
            cell.mediaView.paused = true
            pausedForViewer.append(cell.mediaView)
        }
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, originalViewForItemAt index: Int) -> UIView {
        let cell = visibleCell(at: index)
        return cell
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, transitionImageForItemAt index: Int) -> UIImage? {
        let cell = visibleCell(at: index)
        return cell.mediaView.snapshotImage()
    }

    func visibleCell(at index: Int) -> PagedMediaCell {
        guard let collectionView else { fatalError() }

        let indexPath = IndexPath(item: index, section: 0)

        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            // Important: Ensure the cell is visible and laid out before accessing it
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            collectionView.layoutIfNeeded()
        }

        return collectionView.visibleCells.first(where: { collectionView.indexPath(for: $0) == indexPath }) as! PagedMediaCell
    }
}

// MARK: `PagedMediaDelegate`
extension PagedMediaViewControllerExample: PagedMediaDelegate {
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, willTransitionTo index: Int) {
        collectionView?.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredVertically, animated: false)
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, didTransitionTo toIndex: Int, fromIndex: Int) {
        pageCountLabel?.text = "\(toIndex + 1)/\(fetchResult.count)"
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, willDismissToOriginalViewAt index: Int, fromPagedMediaItem mediaItem: any PagedMediaItem) {
        let mediaView = mediaItem as! MediaView
        let originalMediaView = visibleCell(at: index).mediaView
        guard originalMediaView.isAnimated == true else { return }

        // Hold the same frame as the dismissed item, playback resumes once the transition ends
        resumesPlaybackAfterDismiss = !mediaItem.paused
        originalMediaView.paused = true
        originalMediaView.syncVideoTime(with: mediaView, exact: true)
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, didDismissToOriginalViewAt index: Int) {
        let originalMediaView = visibleCell(at: index).mediaView
        pausedForViewer.filter { $0 !== originalMediaView }.forEach { $0.paused = false }
        pausedForViewer.removeAll()

        guard resumesPlaybackAfterDismiss else { return }

        resumesPlaybackAfterDismiss = false
        originalMediaView.paused = false
    }
}

// MARK: Custom header and footer for PagedMediaViewController
extension PagedMediaViewControllerExample {
    private func setupFooterHeader(for vc: PagedMediaViewController) {
        // Footer
        let footerStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .equalCentering
            return stackView
        }()

        let imageNames = [
            "externaldrive",
            "tray.and.arrow.down",
            "eraser",
            "highlighter",
            "ruler"
        ]

        for imageName in imageNames {
            let button = UIButton()
            button.tintColor = .white
            button.setImage(UIImage(systemName: imageName), for: .normal)
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            footerStackView.addArrangedSubview(button)
        }

        vc.footerViewContainer.backgroundColor = .black.withAlphaComponent(0.5)
        vc.footerViewContainer.addSubview(footerStackView)

        footerStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerStackView.leadingAnchor.constraint(equalTo: vc.footerViewContainer.layoutMarginsGuide.leadingAnchor),
            footerStackView.topAnchor.constraint(equalTo: vc.footerViewContainer.layoutMarginsGuide.topAnchor),
            footerStackView.trailingAnchor.constraint(equalTo: vc.footerViewContainer.layoutMarginsGuide.trailingAnchor),
            footerStackView.bottomAnchor.constraint(equalTo: vc.footerViewContainer.layoutMarginsGuide.bottomAnchor)
        ])


        // Header
        let closeButton = UIButton()
        closeButton.accessibilityIdentifier = "closeButton"
        closeButton.tintColor = .white
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        vc.headerViewContainer.backgroundColor = .black.withAlphaComponent(0.5)
        vc.headerViewContainer.addSubview(closeButton)

        closeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: vc.headerViewContainer.layoutMarginsGuide.leadingAnchor),
            closeButton.topAnchor.constraint(equalTo: vc.headerViewContainer.layoutMarginsGuide.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: vc.headerViewContainer.layoutMarginsGuide.bottomAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        let pageCountLabel = UILabel()
        pageCountLabel.textColor = .white
        pageCountLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        vc.headerViewContainer.addSubview(pageCountLabel)
        pageCountLabel.text = "\(vc.initialIndex + 1)/\(fetchResult.count)"
        self.pageCountLabel = pageCountLabel

        pageCountLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pageCountLabel.centerXAnchor.constraint(equalTo: vc.headerViewContainer.layoutMarginsGuide.centerXAnchor),
            pageCountLabel.centerYAnchor.constraint(equalTo: vc.headerViewContainer.layoutMarginsGuide.centerYAnchor)
        ])
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}
