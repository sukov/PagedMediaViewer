//
//  PagedMediaViewerUITests.swift
//  PagedMediaViewerUITests
//
//  Created by Gorjan Shukov on 30.9.25.
//

import XCTest

final class PagedMediaViewerUITests: XCTestCase {

    // MARK: - Properties

    private var app: XCUIApplication!

    private enum Timeout {
        static let short: TimeInterval = 1
        static let medium: TimeInterval = 2
        static let long: TimeInterval = 3
    }

    private enum Animation {
        static let standard: UInt32 = UInt32(0.5)
        static let short: UInt32 = 1
    }

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Element Getters

    private var collectionView: XCUIElement {
        app.collectionViews.firstMatch
    }

    private var mediaViewer: XCUIElement {
        app.otherElements["pagedMediaViewController"]
    }

    private var mediaScrollView: XCUIElement {
        app.scrollViews.firstMatch
    }

    private var closeButton: XCUIElement {
        app.buttons["closeButton"].firstMatch
    }

    private var pageLabel: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "\\d+/\\d+")).firstMatch
    }

    // MARK: - Helper Methods - Setup

    @discardableResult
    private func launchMediaViewer(fromCellAt index: Int = 0) -> Bool {
        guard collectionView.waitForExistence(timeout: Timeout.long) else {
            XCTFail("Collection view failed to load")
            return false
        }

        let cell = collectionView.cells.element(boundBy: index)
        guard cell.waitForExistence(timeout: Timeout.medium) else {
            XCTFail("Cell at index \(index) not found")
            return false
        }

        cell.tap()
        return waitForMediaViewerToLoad()
    }

    @discardableResult
    private func waitForMediaViewerToLoad() -> Bool {
        let loaded = mediaViewer.waitForExistence(timeout: Timeout.medium)
        if !loaded {
            XCTFail("Media viewer failed to load")
        }
        return loaded
    }

    // MARK: - Helper Methods - Actions

    private func navigateLeft() {
        mediaViewer.swipeLeft()
        sleep(Animation.standard)
    }

    private func navigateRight() {
        mediaViewer.swipeRight()
        sleep(Animation.standard)
    }

    private func dismissViewer() {
        mediaViewer.swipeDown()
    }

    private func doubleTapMedia() {
        mediaScrollView.doubleTap()
        sleep(Animation.standard)
    }

    private func tapMedia() {
        mediaScrollView.tap()
        sleep(Animation.short)
    }

    private func rotateToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(Animation.standard)
    }

    private func rotateToPortrait() {
        XCUIDevice.shared.orientation = .portrait
        sleep(Animation.standard)
    }

    // MARK: - Helper Methods - Assertions

    private func assertCollectionViewVisible() {
        XCTAssertTrue(
            collectionView.waitForExistence(timeout: Timeout.short),
            "Collection view should be visible"
        )
    }

    private func assertMediaViewerVisible() {
        XCTAssertTrue(mediaViewer.exists, "Media viewer should be visible")
        XCTAssertTrue(mediaScrollView.exists, "Media scroll view should be visible")
    }

    private func assertPageLabel(hasPrefix prefix: String) {
        XCTAssertTrue(
            pageLabel.waitForExistence(timeout: Timeout.short),
            "Page label should exist"
        )
        XCTAssertTrue(
            pageLabel.label.hasPrefix(prefix),
            "Page label should start with '\(prefix)', but was '\(pageLabel.label)'"
        )
    }

    // MARK: - Basic Flow Tests

    func testMediaViewerPresentation() {
        // When: Launch media viewer
        launchMediaViewer()

        // Then: Media viewer should be presented with scroll view
        assertMediaViewerVisible()
    }

    func testMediaViewerDismissalBySwipe() {
        // Given: Media viewer is presented
        launchMediaViewer()

        // When: Swipe down to dismiss
        dismissViewer()

        // Then: Collection view should be visible again
        assertCollectionViewVisible()
    }

    func testMediaViewerDismissalByCloseButton() {
        // Given: Media viewer is presented
        launchMediaViewer()

        // When: Tap the close button
        XCTAssertTrue(closeButton.waitForExistence(timeout: Timeout.short))
        closeButton.tap()

        // Then: Collection view should be visible again
        assertCollectionViewVisible()
    }

    // MARK: - Navigation Tests

    func testSwipeBetweenMediaItems() {
        // Given: Media viewer is presented with multiple items
        launchMediaViewer()
        XCTAssertTrue(pageLabel.waitForExistence(timeout: Timeout.short))
        let initialPage = pageLabel.label

        // When: Swipe left to next item
        navigateLeft()

        // Then: Page should change
        let nextPage = pageLabel.label
        XCTAssertNotEqual(initialPage, nextPage, "Page should change after swiping left")

        // When: Swipe right to previous item
        navigateRight()

        // Then: Should return to initial page
        XCTAssertEqual(pageLabel.label, initialPage, "Should return to initial page after swiping right")
    }

    func testPageIndicatorUpdates() {
        // Given: Media viewer is presented
        launchMediaViewer()
        XCTAssertTrue(pageLabel.waitForExistence(timeout: Timeout.short))
        let initialLabel = pageLabel.label

        // When: Navigate to next page
        navigateLeft()

        // Then: Page indicator should update with correct format
        let updatedLabel = pageLabel.label
        XCTAssertNotEqual(initialLabel, updatedLabel, "Page label should update after navigation")
        XCTAssertTrue(updatedLabel.contains("/"), "Page label should be in format 'x/y'")
    }

    // MARK: - Zoom Interaction Tests

    func testDoubleTapZoom() {
        // Given: Media viewer is presented
        launchMediaViewer()
        let initialFrame = mediaScrollView.frame

        // When: Double tap to zoom in
        doubleTapMedia()

        // Then: Content should be zoomable (can scroll within zoomed content)
        mediaScrollView.swipeLeft()
        sleep(1)
        XCTAssertTrue(mediaScrollView.isHittable, "Scroll view should remain interactive when zoomed")

        // When: Double tap again to zoom out
        doubleTapMedia()

        // Then: Should return to original dimensions
        let finalFrame = mediaScrollView.frame
        XCTAssertEqual(
            initialFrame.width, finalFrame.width, accuracy: 1.0,
            "Width should return to original after zoom out"
        )
        XCTAssertEqual(
            initialFrame.height, finalFrame.height, accuracy: 1.0,
            "Height should return to original after zoom out"
        )
    }

    func testPinchToZoom() {
        // Given: Media viewer is presented
        launchMediaViewer()
        let initialFrame = mediaScrollView.frame

        // When: Pinch to zoom in
        mediaScrollView.pinch(withScale: 2, velocity: 1)
        sleep(Animation.standard)

        // Then: Should be able to drag within zoomed content
        let startPoint = mediaScrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let endPoint = mediaScrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        startPoint.press(forDuration: 0, thenDragTo: endPoint)
        sleep(1)

        XCTAssertTrue(mediaScrollView.exists, "Scroll view should exist while zoomed")
        XCTAssertTrue(mediaScrollView.isHittable, "Scroll view should be interactive while zoomed")

        // When: Pinch to zoom out
        mediaScrollView.pinch(withScale: 0.5, velocity: -1)
        sleep(Animation.standard)

        // Then: Should return to original dimensions
        let finalFrame = mediaScrollView.frame
        XCTAssertEqual(
            initialFrame.width, finalFrame.width, accuracy: 1.0,
            "Width should return to original after zoom out"
        )
        XCTAssertEqual(
            initialFrame.height, finalFrame.height, accuracy: 1.0,
            "Height should return to original after zoom out"
        )
    }

    // MARK: - Controls Visibility Tests

    func testHeaderAndFooterControlsExist() {
        // Given: Media viewer is presented
        launchMediaViewer()

        // Then: Header controls should exist
        XCTAssertTrue(closeButton.waitForExistence(timeout: Timeout.short), "Close button should exist")
        XCTAssertTrue(pageLabel.exists, "Page label should exist")

        // Then: Footer buttons should exist
        let footerButtons = app.buttons.allElementsBoundByIndex
        XCTAssertGreaterThan(footerButtons.count, 0, "Footer should contain buttons")
    }

    func testMediaInteractionResponsive() {
        // Given: Media viewer is presented
        launchMediaViewer()

        // When: Tap on media
        tapMedia()

        // Then: Media viewer should remain responsive
        XCTAssertTrue(mediaScrollView.isHittable, "Scroll view should remain interactive after tap")
    }

    // MARK: - Orientation Tests

    func testOrientationChanges() {
        // Given: Media viewer is presented in portrait
        launchMediaViewer()

        // When: Rotate to landscape
        rotateToLandscape()

        // Then: Media viewer should adapt
        assertMediaViewerVisible()

        // When: Rotate back to portrait
        rotateToPortrait()

        // Then: Media viewer should still be visible
        assertMediaViewerVisible()
    }

    // MARK: - Performance Tests

    func testMediaViewerLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()

            if collectionView.waitForExistence(timeout: Timeout.short) {
                let firstCell = collectionView.cells.element(boundBy: 0)
                if firstCell.waitForExistence(timeout: 1) {
                    firstCell.tap()
                    _ = mediaViewer.waitForExistence(timeout: 1)
                }
            }
        }
    }

    // MARK: - Accessibility Tests

    func testMediaViewerAccessibility() {
        // Given: Media viewer is presented
        launchMediaViewer()

        // Then: All interactive elements should be accessible and hittable
        XCTAssertTrue(mediaScrollView.isHittable, "Scroll view should be hittable")
        XCTAssertTrue(closeButton.isHittable, "Close button should be hittable")
        XCTAssertTrue(pageLabel.exists, "Page label should be accessible")
    }

    // MARK: - Collection View Integration Tests

    func testLaunchingFromDifferentCells() throws {
        // Given: Collection view with multiple items
        XCTAssertTrue(collectionView.waitForExistence(timeout: Timeout.short))

        // When: Launch from first cell
        launchMediaViewer(fromCellAt: 0)

        // Then: Should start at page 1
        assertPageLabel(hasPrefix: "1/")

        // When: Dismiss and launch from second cell
        dismissViewer()
        assertCollectionViewVisible()

        let secondCell = collectionView.cells.element(boundBy: 1)
        guard secondCell.exists else {
            throw XCTSkip("Second cell not available for testing")
        }

        launchMediaViewer(fromCellAt: 1)

        // Then: Should start at page 2
        assertPageLabel(hasPrefix: "2/")
    }

    func testReturnToCollectionViewAfterDismiss() throws {
        // Given: Collection view is visible
        XCTAssertTrue(collectionView.waitForExistence(timeout: Timeout.short))

        let thirdCell = collectionView.cells.element(boundBy: 2)
        guard thirdCell.exists else {
            throw XCTSkip("Third cell not available for testing")
        }

        // When: View media from third cell and dismiss
        launchMediaViewer(fromCellAt: 2)
        dismissViewer()

        // Then: Should return to collection view
        assertCollectionViewVisible()
    }
}
