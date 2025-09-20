//
//  MediaViewController.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//

import UIKit
import AVFoundation

protocol MediaViewControllerDelegate: AnyObject {
    func mediaViewController(_ mediaViewController: MediaViewController, didZoomToScale zoomedScale: CGFloat, withMinimumScale minScale: CGFloat)
}

protocol MediaViewControllerDataSource: AnyObject {
    var visibleAreaEdgeInsets: UIEdgeInsets { get }
    var isControlsViewHidden: Bool { get }
}

class MediaViewController: UIViewController {
    static let scrollViewTag = 8599
    private let maximumZoomScale: CGFloat = 3
    private var zoomScaleForDoubleTap: CGFloat = 1.4

    // MARK: Layout Constraints
    private var mediaViewLeadingConstraint: NSLayoutConstraint!
    private var mediaViewTopConstraint: NSLayoutConstraint!
    private var mediaViewTrailingConstraint: NSLayoutConstraint!
    private var mediaViewBottomConstraint: NSLayoutConstraint!
    private var controlsViewTopConstraint: NSLayoutConstraint?
    private var controlsViewBottomConstraint: NSLayoutConstraint?

    private var userDidZoom = false

    private let scrollView = UIScrollView()

    let doubleTapRecognizer = UITapGestureRecognizer()
    let index: Int
    let mediaView: PagedMediaItem
    weak var delegate: MediaViewControllerDelegate?
    weak var dataSource: MediaViewControllerDataSource?

    init(index: Int, mediaView: PagedMediaItem) {
        self.index = index
        self.mediaView = mediaView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        makeConstraints()
        addGestureRecognizers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let isControlsHidden = (dataSource?.isControlsViewHidden == true)
        mediaView.animatedItemControlsView?.isHidden = isControlsHidden
        mediaView.animatedItemControlsView?.alpha = isControlsHidden ? 0 : 1
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        mediaView.paused = false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        }

        mediaView.paused = true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        layoutScrollZoomView()

        guard
            let edgeInsets = dataSource?.visibleAreaEdgeInsets,
            controlsViewTopConstraint?.constant != edgeInsets.top
            || controlsViewBottomConstraint?.constant != -edgeInsets.bottom
        else { return }

        controlsViewTopConstraint?.constant = edgeInsets.top
        controlsViewBottomConstraint?.constant = -edgeInsets.bottom
    }

    func attachMediaView(initialSetup: Bool = false) {
        scrollView.addSubview(mediaView)

        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaViewLeadingConstraint = mediaView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
        mediaViewTopConstraint = mediaView.topAnchor.constraint(equalTo: scrollView.topAnchor)
        mediaViewTrailingConstraint = mediaView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor)
        mediaViewBottomConstraint = mediaView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)

        NSLayoutConstraint.activate([
            mediaViewLeadingConstraint,
            mediaViewTopConstraint,
            mediaViewTrailingConstraint,
            mediaViewBottomConstraint
        ])

        guard initialSetup == false else { return }

        view.layoutIfNeeded()
        layoutScrollZoomView()
    }

    func detachMediaView() -> UIView {
        // Remove zoom scale from mediaView for the transition animation to work, otherwise the entire calculation goes wrong.
        mediaView.transform = .identity
        mediaView.removeFromSuperview()

        return mediaView
    }

    private func setupView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
        scrollView.tag = Self.scrollViewTag
        scrollView.pinchGestureRecognizer?.addTarget(self, action: #selector(scrollViewPinchGesture(_:)))

        view.addSubview(scrollView)
        attachMediaView(initialSetup: true)

        guard let controlsView = mediaView.animatedItemControlsView else { return }

        view.addSubview(controlsView)
    }

    private func makeConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        guard let controlsView = mediaView.animatedItemControlsView else { return }

        controlsView.translatesAutoresizingMaskIntoConstraints = false
        controlsViewTopConstraint = controlsView.topAnchor.constraint(equalTo: view.topAnchor)
        controlsViewBottomConstraint = controlsView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            controlsViewTopConstraint!,
            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsViewBottomConstraint!
        ])
    }
}

// MARK: - Gesture Recognizers

extension MediaViewController {
    private func addGestureRecognizers() {
        doubleTapRecognizer.addTarget(self, action: #selector(didDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(doubleTapRecognizer)
    }

    @objc private func didDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            userDidZoom = false
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            userDidZoom = true
            scrollView.zoom(to: zoomRectForScale(scale: zoomScaleForDoubleTap, center: recognizer.location(in: mediaView)), animated: true)
        }
    }

    @objc private func scrollViewPinchGesture(_ gesture: UIPinchGestureRecognizer) {
        userDidZoom = (scrollView.zoomScale > scrollView.minimumZoomScale)
    }
}

// MARK: - Zooming

extension MediaViewController {
    private func layoutScrollZoomView() {
        updateConstraintsForSize(view.bounds.size)
        updateMinZoomScaleForSize(view.bounds.size)
    }

    private func updateMinZoomScaleForSize(_ size: CGSize) {
        guard mediaView.superview === scrollView else { return } // avoid setting zoom scale for detached media view

        let widthScale = size.width / mediaView.bounds.width
        let heightScale = size.height / mediaView.bounds.height
        let minScale = min(widthScale, heightScale)
        let maxScale = max(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        if !userDidZoom { scrollView.zoomScale = minScale }
        let shouldUseMaxScale = (mediaView.bounds.width > size.width) || ((maxScale - minScale) > 0.1)
        zoomScaleForDoubleTap = shouldUseMaxScale ? maxScale : 1.4

        if scrollView.maximumZoomScale < zoomScaleForDoubleTap {
            // Always make sure maximumZoomScale is at least zoomScaleForDoubleTap
            scrollView.maximumZoomScale = zoomScaleForDoubleTap
        }
    }

    private func updateConstraintsForSize(_ size: CGSize) {
        guard size != .zero else { return }

        let yOffset = max(0, (size.height - mediaView.frame.height) / 2)
        mediaViewTopConstraint.constant = yOffset
        mediaViewBottomConstraint.constant = yOffset

        let xOffset = max(0, (size.width - mediaView.frame.width) / 2)
        mediaViewLeadingConstraint.constant = xOffset
        mediaViewTrailingConstraint.constant = xOffset

        view.layoutIfNeeded()
    }

    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = mediaView.frame.size.height / scale
        zoomRect.size.width  = mediaView.frame.size.width  / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
}

extension MediaViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        mediaView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(view.bounds.size)
        delegate?.mediaViewController(self, didZoomToScale: scrollView.zoomScale, withMinimumScale: scrollView.minimumZoomScale)
    }
}
