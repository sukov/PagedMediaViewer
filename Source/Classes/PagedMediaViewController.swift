//
//  PagedMediaViewController.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//

import UIKit

/// Data source for providing media items and original views for transition animations.
public protocol PagedMediaDataSource: AnyObject {
    /// Number of items to be presented.
    func numberOfItems(in pagedMediaViewController: PagedMediaViewController) -> Int
    /// Adds insets  on `PagedMediaViewController`'s view presentation frame. Defaults to `.zero`. Useful for preventing presentation over promotional content.
    func presentationViewInsets(for pagedMediaViewController: PagedMediaViewController) -> UIEdgeInsets
    /// Provides the media item view for the given index.
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, pagedMediaViewForItemAt index: Int) -> PagedMediaItem
    /// Provides the original view for the given index. Used for transition animations.
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, originalViewForItemAt index: Int) -> UIView
    /// Optional method for specifying the original image for the view or a snapshot. By default `PagedMediaTransitionDriver` will create a snapshot from the original view.
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, transitionImageForItemAt index: Int) -> UIImage?
}

public extension PagedMediaDataSource {
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, transitionImageForItemAt index: Int) -> UIImage? {
        self.pagedMediaViewController(pagedMediaViewController, originalViewForItemAt: index).snapshotImage()
    }

    func presentationViewInsets(for pagedMediaViewController: PagedMediaViewController) -> UIEdgeInsets {
        .zero
    }
}

/// Delegate for transition and item change events.
public protocol PagedMediaDelegate: AnyObject {
    /// Called just before the transition to a new item begins. Useful for centering table/collection view items behind the scenes for proper transition animation.
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, willTransitionTo index: Int)
    /// Called after the transition to a new item is completed.
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, didTransitionTo toIndex: Int, fromIndex: Int)
    /// Called just before the transition ends. Perfect time to unpause the original view at index.
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                     willDismissToOriginalViewAt index: Int,
                                     fromPagedMediaItem mediaItem: PagedMediaItem)
}

/// The main view controller for presenting and paging through media items.
open class PagedMediaViewController: UIPageViewController {
    /// Index of the item to be presented first.
    public let initialIndex: Int
    /// Header view container. Add your custom header views here.
    public let headerViewContainer = UIView()
    /// Footer view container. Add your custom footer views here.
    public let footerViewContainer = UIView()
    /// Data source for providing the media items and original views.
    public weak var pagedMediaDataSource: PagedMediaDataSource?
    /// Delegate for transition and item change events.
    public weak var pagedMediaDelegate: PagedMediaDelegate?
    /// Current index of the presented item.
    public var currentIndex: Int {
        currentViewController?.index ?? 0
    }

    /// Hidden status bar when header/footer are hidden.
    public override var prefersStatusBarHidden: Bool {
        isHeaderFooterHidden
    }
    /// Light content status bar style.
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    private var isHeaderFooterHidden = false
    private var shouldDisplayHeaderFooterOnZoomOut = true
    private let pagedMediaTransitionController = PagedMediaTransitionController()
    private let pageOptions = [
        UIPageViewController.OptionsKey.interPageSpacing: 20
    ]
    private lazy var lastWillTransitionToIndex = initialIndex
    private let tapRecognizer = UITapGestureRecognizer()

    var currentViewController: MediaViewController? {
        viewControllers?.first as? MediaViewController
    }

    var presentationViewInsets: UIEdgeInsets {
        pagedMediaDataSource?.presentationViewInsets(for: self) ?? .zero
    }

    /// Initializes the paged media view controller with the given initial index of the media item.
    public init(initialIndex: Int) {
        self.initialIndex = initialIndex
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: pageOptions)

        transitioningDelegate = pagedMediaTransitionController
        modalPresentationStyle = .custom
        modalPresentationCapturesStatusBarAppearance = true
    }

    /// Not implemented.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        dataSource = self

        setupView()
        makeConstraints()
        addGestureRecognizers()
    }

    private func setupView() {
        if view.backgroundColor == nil {
            // Defaults to black if not set from superclass
            view.backgroundColor = .black
        }

        let mediaVC = makeViewController(for: initialIndex)
        mediaVC.delegate = self
        setViewControllers([mediaVC], direction: .forward, animated: false)

        view.addSubview(headerViewContainer)
        view.addSubview(footerViewContainer)
    }

    private func makeConstraints() {
        headerViewContainer.translatesAutoresizingMaskIntoConstraints = false
        footerViewContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerViewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            headerViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            footerViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerViewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func addGestureRecognizers() {
        tapRecognizer.addTarget(self, action: #selector(didTap))
        tapRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(tapRecognizer)
    }

    private func makeViewController(for index: Int) -> MediaViewController {
        guard let pagedMediaDataSource else {
            fatalError("mediaDataSource is nil")
        }

        let itemView = pagedMediaDataSource.pagedMediaViewController(self, pagedMediaViewForItemAt: index)
        let vc = MediaViewController(index: index, mediaView: itemView)
        vc.dataSource = self
        vc.view.backgroundColor = view.backgroundColor
        tapRecognizer.require(toFail: vc.doubleTapRecognizer)

        return vc
    }

    @objc private func didTap() {
        let shouldHide = !isHeaderFooterHidden
        shouldDisplayHeaderFooterOnZoomOut = !shouldHide
        animateHeaderFooter(hidden: shouldHide)
    }

    private func animateHeaderFooter(hidden: Bool) {
        isHeaderFooterHidden = hidden
        let controlsView = currentViewController?.mediaView.animatedItemControlsView

        if isHeaderFooterHidden == false {
            // Reset values for presenting
            headerViewContainer.alpha = 0
            footerViewContainer.alpha = 0
            controlsView?.alpha = 0
            headerViewContainer.isHidden = isHeaderFooterHidden
            footerViewContainer.isHidden = isHeaderFooterHidden
            controlsView?.isHidden = isHeaderFooterHidden
        }

        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = self.isHeaderFooterHidden ? 0 : 1
            self.headerViewContainer.alpha = alpha
            self.footerViewContainer.alpha = alpha
            controlsView?.alpha = alpha
            self.setNeedsStatusBarAppearanceUpdate()
        } completion: { _ in
            self.headerViewContainer.isHidden = self.isHeaderFooterHidden
            self.footerViewContainer.isHidden = self.isHeaderFooterHidden
            controlsView?.isHidden = self.isHeaderFooterHidden
        }
    }
}

extension PagedMediaViewController: UIPageViewControllerDelegate {
    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let vc = pendingViewControllers.first as? MediaViewController else { return }

        // Remove delegate to avoid zoomScale resetting delegate calls
        currentViewController?.delegate = nil
        lastWillTransitionToIndex = vc.index
        pagedMediaDelegate?.pagedMediaViewController(self, willTransitionTo: vc.index)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let previousIndex = (previousViewControllers.first as? MediaViewController)?.index else { return }

        currentViewController?.delegate = self

        if currentIndex != lastWillTransitionToIndex {
            // We tranistioned back to the same index, inform delegate for proper item position
            pagedMediaDelegate?.pagedMediaViewController(self, willTransitionTo: currentIndex)
        } else {
            // Transition was succesfull to new index
            shouldDisplayHeaderFooterOnZoomOut = !isHeaderFooterHidden
            pagedMediaDelegate?.pagedMediaViewController(self, didTransitionTo: currentIndex, fromIndex: previousIndex)
        }
    }
}

extension PagedMediaViewController: UIPageViewControllerDataSource {
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard
            let vc = viewController as? MediaViewController,
            vc.index > 0
        else { return nil }

        let newIndex = vc.index - 1
        return makeViewController(for: newIndex)
    }

    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard
            let vc = viewController as? MediaViewController,
            let pagedMediaDataSource,
            vc.index < (pagedMediaDataSource.numberOfItems(in: self) - 1)
        else { return nil }

        let newIndex = vc.index + 1
        return makeViewController(for: newIndex)
    }
}

extension PagedMediaViewController: MediaViewControllerDelegate {
    func mediaViewController(_ mediaViewController: MediaViewController, didZoomToScale zoomedScale: CGFloat, withMinimumScale minScale: CGFloat) {
        if isHeaderFooterHidden && shouldDisplayHeaderFooterOnZoomOut && zoomedScale == minScale {
            animateHeaderFooter(hidden: false)
        } else if isHeaderFooterHidden == false && zoomedScale > minScale {
            animateHeaderFooter(hidden: true)
        }
    }
}

extension PagedMediaViewController: MediaViewControllerDataSource {
    var visibleAreaEdgeInsets: UIEdgeInsets {
        let top = headerViewContainer.bounds.height > 0 ? headerViewContainer.bounds.height : view.safeAreaInsets.top
        let bottom = footerViewContainer.bounds.height > 0 ? footerViewContainer.bounds.height : view.safeAreaInsets.bottom

        return UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    }

    var isControlsViewHidden: Bool {
        isHeaderFooterHidden
    }
}
