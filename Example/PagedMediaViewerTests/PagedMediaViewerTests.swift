//
//  PagedMediaViewerTests.swift
//  PagedMediaViewerTests
//
//  Created by Gorjan Shukov on 25.9.25.
//

import UIKit
import XCTest
@testable import PagedMediaViewer

// MARK: - Mock Classes for Testing

class MockPagedMediaItem: UIView, PagedMediaItem {
    var paused: Bool = false
    var isAnimated: Bool = false
    var animatedItemSnapshotAtCurrentTime: UIImage?
    var animatedItemControlsView: UIView?

    init(isAnimated: Bool = false, hasControls: Bool = false) {
        super.init(frame: .zero)
        self.isAnimated = isAnimated

        if hasControls {
            let controlsView = UIView()
            controlsView.backgroundColor = .blue
            controlsView.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
            self.animatedItemControlsView = controlsView
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MockPagedMediaDataSource: PagedMediaDataSource {
    var numberOfItemsToReturn = 3
    var presentationInsets = UIEdgeInsets.zero

    func numberOfItems(in pagedMediaViewController: PagedMediaViewController) -> Int {
        return numberOfItemsToReturn
    }

    func presentationViewInsets(for pagedMediaViewController: PagedMediaViewController) -> UIEdgeInsets {
        return presentationInsets
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, pagedMediaViewForItemAt index: Int) -> PagedMediaItem {
        return MockPagedMediaItem(isAnimated: index == 0) // First item is animated
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, originalViewForItemAt index: Int) -> UIView {
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        return view
    }
}

class MockPagedMediaDelegate: PagedMediaDelegate {
    var willTransitionToIndex: Int?
    var didTransitionToIndex: Int?
    var didTransitionFromIndex: Int?
    var willDismissIndex: Int?

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, willTransitionTo index: Int) {
        willTransitionToIndex = index
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, didTransitionTo toIndex: Int, fromIndex: Int) {
        didTransitionToIndex = toIndex
        didTransitionFromIndex = fromIndex
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, willDismissToOriginalViewAt index: Int, fromPagedMediaItem mediaItem: PagedMediaItem) {
        willDismissIndex = index
    }
}

class MockMediaViewControllerDataSource: MediaViewControllerDataSource {
    var visibleAreaEdgeInsets: UIEdgeInsets = .zero
    var isControlsViewHidden: Bool = false
}

class ShapedSourceDataSource: MockPagedMediaDataSource {
    let originalView: UIView

    init(originalView: UIView) {
        self.originalView = originalView
    }

    override func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, originalViewForItemAt index: Int) -> UIView {
        return originalView
    }
}

class MockTransitionContext: NSObject, UIViewControllerContextTransitioning {
    let containerView: UIView
    let isAnimated = true
    let isInteractive: Bool
    let presentationStyle: UIModalPresentationStyle = .custom
    let targetTransform: CGAffineTransform = .identity
    private(set) var transitionWasCancelled = false
    private(set) var completedTransitions: [Bool] = []
    private let viewControllers: [UITransitionContextViewControllerKey: UIViewController]

    init(containerView: UIView, from: UIViewController, to: UIViewController, isInteractive: Bool) {
        self.containerView = containerView
        self.isInteractive = isInteractive
        self.viewControllers = [.from: from, .to: to]
    }

    func updateInteractiveTransition(_ percentComplete: CGFloat) {}
    func finishInteractiveTransition() {}
    func cancelInteractiveTransition() { transitionWasCancelled = true }
    func pauseInteractiveTransition() {}

    func completeTransition(_ didComplete: Bool) {
        completedTransitions.append(didComplete)
    }

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        return viewControllers[key]
    }

    func view(forKey key: UITransitionContextViewKey) -> UIView? {
        return key == .from ? viewControllers[.from]?.view : viewControllers[.to]?.view
    }

    func initialFrame(for vc: UIViewController) -> CGRect { containerView.bounds }
    func finalFrame(for vc: UIViewController) -> CGRect { containerView.bounds }
}

// MARK: - Test Cases

@MainActor
class PagedMediaViewerTests: XCTestCase {
    var pagedMediaViewController: PagedMediaViewController!
    var mockDataSource: MockPagedMediaDataSource!
    var mockDelegate: MockPagedMediaDelegate!

    override func setUp() {
        super.setUp()
        mockDataSource = MockPagedMediaDataSource()
        mockDelegate = MockPagedMediaDelegate()

        pagedMediaViewController = PagedMediaViewController(initialIndex: 0)
        pagedMediaViewController.pagedMediaDataSource = mockDataSource
        pagedMediaViewController.pagedMediaDelegate = mockDelegate

        // Load view to trigger viewDidLoad
        _ = pagedMediaViewController.view
    }

    override func tearDown() {
        pagedMediaViewController = nil
        mockDataSource = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - PagedMediaViewController Tests

    func testInitialization() {
        XCTAssertEqual(pagedMediaViewController.initialIndex, 0)
        XCTAssertNotNil(pagedMediaViewController.headerViewContainer)
        XCTAssertNotNil(pagedMediaViewController.footerViewContainer)
        XCTAssertTrue(pagedMediaViewController.modalPresentationCapturesStatusBarAppearance)
    }

    func testCurrentIndex() {
        XCTAssertEqual(pagedMediaViewController.currentIndex, 0)
    }

    // MARK: - MediaViewController Tests

    func testMediaViewControllerInitialization() {
        let mediaItem = MockPagedMediaItem()
        let mediaVC = MediaViewController(index: 0, mediaView: mediaItem)

        XCTAssertEqual(mediaVC.index, 0)
        XCTAssertIdentical(mediaVC.mediaView, mediaItem)
    }

    func testMediaViewControllerLifecycle() {
        let mediaItem = MockPagedMediaItem(isAnimated: true)
        let mediaVC = MediaViewController(index: 0, mediaView: mediaItem)

        // Load view
        _ = mediaVC.view

        // Test view appearance
        mediaVC.viewWillAppear(false)
        mediaVC.viewDidAppear(false)
        XCTAssertFalse(mediaItem.paused)

        mediaVC.viewDidDisappear(false)
        XCTAssertTrue(mediaItem.paused)
    }

    @MainActor
    func testMediaViewControllerZoom() {
        let mediaItem = MockPagedMediaItem()
        let mediaVC = MediaViewController(index: 0, mediaView: mediaItem)
        let mockDataSource = MockMediaViewControllerDataSource()
        mediaVC.dataSource = mockDataSource

        // Load view to setup scroll view
        _ = mediaVC.view

        // Test initial zoom scale
        let scrollView = mediaVC.view.subviews.first { $0 is UIScrollView } as? UIScrollView
        XCTAssertNotNil(scrollView)
        XCTAssertEqual(scrollView?.minimumZoomScale, 1.0) // Will be updated in layout

        // Test double tap gesture
        let doubleTapRecognizer = mediaVC.doubleTapRecognizer
        XCTAssertEqual(doubleTapRecognizer.numberOfTapsRequired, 2)
        XCTAssertEqual(doubleTapRecognizer.numberOfTouchesRequired, 1)
    }

    // MARK: - PagedMediaItem Tests

    func testPagedMediaItemProtocol() {
        let mediaItem = MockPagedMediaItem(isAnimated: true, hasControls: true)

        XCTAssertTrue(mediaItem.isAnimated)
        XCTAssertNotNil(mediaItem.animatedItemControlsView)

        // Test pausing
        mediaItem.paused = true
        XCTAssertTrue(mediaItem.paused)

        mediaItem.paused = false
        XCTAssertFalse(mediaItem.paused)
    }

    func testPagedMediaItemDefaultImplementations() {
        let mediaItem = MockPagedMediaItem()

        // Test default implementations
        XCTAssertNil(mediaItem.animatedItemSnapshotAtCurrentTime)
        XCTAssertNil(mediaItem.animatedItemControlsView)
    }

    // MARK: - UIView Extension Tests

    func testSnapshotImage() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.backgroundColor = .red

        let snapshot = view.snapshotImage()
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.size, view.bounds.size)
    }

    // MARK: - Data Source Default Implementations

    func testDataSourceDefaultImplementations() {
        let dataSource = MockPagedMediaDataSource()
        let pagedMediaVC = PagedMediaViewController(initialIndex: 0)

        let transitionImage = dataSource.pagedMediaViewController(pagedMediaVC, transitionImageForItemAt: 0)
        XCTAssertNotNil(transitionImage) // Should use snapshot from default implementation

        let insets = dataSource.presentationViewInsets(for: pagedMediaVC)
        XCTAssertEqual(insets, .zero)
    }

    // MARK: - PagedMediaSource

    func testSourceFromViewReadsWindowFrameAndTogglesAlpha() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = UIView(frame: CGRect(x: 30, y: 40, width: 100, height: 60))
        window.addSubview(view)

        let source = PagedMediaSource(view: view)

        XCTAssertEqual(source.frameInWindow, CGRect(x: 30, y: 40, width: 100, height: 60))

        source.setHidden(true)
        XCTAssertEqual(view.alpha, 0)

        source.setHidden(false)
        XCTAssertEqual(view.alpha, 1)
    }

    func testSourceFromViewReadsCornersAndAspectFill() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        view.layer.cornerRadius = 12
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.contentMode = .scaleAspectFill

        let source = PagedMediaSource(view: view)

        XCTAssertEqual(source.cornerRadius, 12)
        XCTAssertEqual(source.maskedCorners, [.layerMinXMinYCorner, .layerMaxXMinYCorner])
        XCTAssertEqual(source.contentMode, .scaleAspectFill)
    }

    func testSourceFromViewTreatsNonFillContentModesAsAspectFit() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        view.contentMode = .scaleToFill

        XCTAssertEqual(PagedMediaSource(view: view).contentMode, .scaleAspectFit)
    }

    func testSourceDefaultsKeepTheUnroundedAspectFitTransition() {
        let source = PagedMediaSource(frameInWindow: CGRect(x: 0, y: 0, width: 10, height: 10))

        XCTAssertEqual(source.cornerRadius, 0)
        XCTAssertEqual(source.maskedCorners, .allCorners)
        XCTAssertEqual(source.contentMode, .scaleAspectFit)
    }

    func testDataSourceDefaultSourceBridgesToOriginalView() {
        let dataSource = MockPagedMediaDataSource()
        let pagedMediaVC = PagedMediaViewController(initialIndex: 0)

        let source = dataSource.pagedMediaViewController(pagedMediaVC, originalSourceForItemAt: 0)

        // Mock view is 100x100 and not in a window
        XCTAssertEqual(source.frameInWindow.size, CGSize(width: 100, height: 100))
    }

    // MARK: - PagedMediaSourceRegistry

    func testRegistryHasNoSourceForUnrecordedItem() {
        // Retained by the window, `containerView` is weak
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let container = UIView(frame: window.bounds)
        window.addSubview(container)

        let registry = PagedMediaSourceRegistry()
        registry.containerView = container

        XCTAssertNotNil(registry.containerView)
        XCTAssertNil(registry.source(for: AnyHashable("missing")))
    }

    func testRegistryConvertsRecordedFrameIntoWindowSpace() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let container = UIView(frame: CGRect(x: 0, y: 100, width: 320, height: 380))
        window.addSubview(container)

        let registry = PagedMediaSourceRegistry()
        registry.containerView = container
        registry.record(AnyHashable("item"), frameInContainer: CGRect(x: 10, y: 20, width: 80, height: 90))

        let source = registry.source(for: AnyHashable("item"))

        XCTAssertEqual(source?.frameInWindow, CGRect(x: 10, y: 120, width: 80, height: 90))
    }

    func testRegistrySourceHidesAndRevealsItsItem() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let container = UIView(frame: window.bounds)
        window.addSubview(container)

        let registry = PagedMediaSourceRegistry()
        registry.containerView = container
        registry.record(AnyHashable("item"), frameInContainer: CGRect(x: 0, y: 0, width: 10, height: 10))

        let source = registry.source(for: AnyHashable("item"))
        XCTAssertNil(registry.hiddenID)

        source?.setHidden(true)
        XCTAssertEqual(registry.hiddenID, AnyHashable("item"))

        source?.setHidden(false)
        XCTAssertNil(registry.hiddenID)
    }

    func testRegistryFallbackSourceIsCenteredInContainer() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let container = UIView(frame: window.bounds)
        window.addSubview(container)

        let registry = PagedMediaSourceRegistry()
        registry.containerView = container

        let frame = registry.fallbackSource().frameInWindow

        XCTAssertEqual(frame.midX, container.bounds.midX)
        XCTAssertEqual(frame.midY, container.bounds.midY)
        XCTAssertGreaterThan(frame.width, 0)
    }

    // MARK: - PagedMediaTransitionDriver

    private func makeTransitionWindow() -> (UIWindow, UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()

        return (window, presenter)
    }

    func testPresentationStartsWithTheSourceShape() {
        let (window, presenter) = makeTransitionWindow()
        let thumbnail = UIView(frame: CGRect(x: 20, y: 100, width: 120, height: 90))
        thumbnail.layer.cornerRadius = 16
        thumbnail.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        thumbnail.contentMode = .scaleAspectFill
        presenter.view.addSubview(thumbnail)

        let dataSource = ShapedSourceDataSource(originalView: thumbnail)
        let viewer = PagedMediaViewController(initialIndex: 0)
        viewer.pagedMediaDataSource = dataSource
        viewer.loadViewIfNeeded()

        let containerView = UIView(frame: window.bounds)
        window.addSubview(containerView)
        let context = MockTransitionContext(containerView: containerView, from: presenter, to: viewer, isInteractive: true)
        let driver = PagedMediaTransitionDriver(transitionDirection: .presentation,
                                                context: context,
                                                panGestureRecognizer: UIPanGestureRecognizer())

        let mediaView = containerView.subviews.compactMap { $0 as? UIImageView }.first

        XCTAssertEqual(mediaView?.layer.cornerRadius, 16)
        XCTAssertEqual(mediaView?.layer.maskedCorners, [.layerMinXMinYCorner, .layerMaxXMinYCorner])
        XCTAssertEqual(mediaView?.contentMode, .scaleAspectFill)
        XCTAssertNotNil(driver)
    }

    func testCancelledDismissalReattachesTheMediaWithItsOwnShapeAfterItLands() {
        let (window, presenter) = makeTransitionWindow()
        let thumbnail = UIView(frame: CGRect(x: 20, y: 100, width: 120, height: 90))
        thumbnail.layer.cornerRadius = 16
        presenter.view.addSubview(thumbnail)

        let dataSource = ShapedSourceDataSource(originalView: thumbnail)
        let viewer = PagedMediaViewController(initialIndex: 1)
        viewer.pagedMediaDataSource = dataSource
        viewer.loadViewIfNeeded()

        let mediaView = viewer.currentViewController!.mediaView
        mediaView.layer.cornerRadius = 7
        mediaView.layer.maskedCorners = [.layerMinXMaxYCorner]
        mediaView.clipsToBounds = false
        let scrollView = mediaView.superview

        let containerView = UIView(frame: window.bounds)
        window.addSubview(containerView)
        let context = MockTransitionContext(containerView: containerView, from: viewer, to: presenter, isInteractive: true)
        let driver = PagedMediaTransitionDriver(transitionDirection: .dismissal,
                                                context: context,
                                                panGestureRecognizer: UIPanGestureRecognizer())

        XCTAssertTrue(mediaView.superview === containerView)

        driver.endInteraction()

        let landed = expectation(description: "transition completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { landed.fulfill() }
        wait(for: [landed], timeout: 2)

        XCTAssertEqual(context.completedTransitions, [false])
        XCTAssertTrue(mediaView.superview === scrollView)
        XCTAssertEqual(mediaView.layer.cornerRadius, 7)
        XCTAssertEqual(mediaView.layer.maskedCorners, [.layerMinXMaxYCorner])
        XCTAssertFalse(mediaView.clipsToBounds)
    }
}
