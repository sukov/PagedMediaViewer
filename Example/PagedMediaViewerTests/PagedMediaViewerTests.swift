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

// MARK: - Test Cases

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
}
