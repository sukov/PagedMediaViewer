//
//  PagedMediaTransitionDriver.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//

import UIKit
import AVKit

@MainActor
class PagedMediaTransitionDriver: NSObject {
    // MARK: - Properties

    private let transitionDirection: PresentationDirection
    private let transitionContext: UIViewControllerContextTransitioning
    private let panGestureRecognizer: UIPanGestureRecognizer

    private var itemFrameAnimator: UIViewPropertyAnimator?
    private var interactiveItem: PagedMediaTransitionItem?
    private var transitionAnimatorCompletion: ((UIViewAnimatingPosition) -> Void)?
    private var transitionAnimatorDidExecuteEndCompletion = false
    private var transitionAnimator: UIViewPropertyAnimator!
    private var headerFooterAnimator: UIViewPropertyAnimator!
    private var tapStealingView: UIView!

    // MARK: - PagedMediaViewController Properties

    private let pagedMediaViewController: PagedMediaViewController
    private let currentMediaViewController: MediaViewController
    private let originalView: UIView
    private let originalTransitionViews: (fromView: UIView, toView: UIView)
    private let presentationTransitionImage: UIImage?

    // MARK: - Computed Properties

    nonisolated
    private class var animationDuration: TimeInterval {
        PagedMediaTransitionController.transitionDuration
    }

    var isInteractive: Bool {
        transitionContext.isInteractive
    }

    // MARK: - Initialization

    init(transitionDirection: PresentationDirection,
         context: UIViewControllerContextTransitioning,
         panGestureRecognizer panGesture: UIPanGestureRecognizer) {

        self.transitionContext = context
        self.transitionDirection = transitionDirection
        self.panGestureRecognizer = panGesture

        // Initialize PagedMediaViewController properties
        let (pagedMediaVC, currentMediaVC) = Self.extractViewControllers(
            from: context,
            direction: transitionDirection
        )
        self.pagedMediaViewController = pagedMediaVC
        self.currentMediaViewController = currentMediaVC

        // Initialize view properties
        self.originalView = Self.getOriginalView(
            from: pagedMediaVC,
            at: currentMediaVC.index
        )
        self.originalTransitionViews = Self.createTransitionViews(
            originalView: originalView,
            currentMediaViewController: currentMediaVC,
            direction: transitionDirection
        )
        self.presentationTransitionImage = Self.getPresentationTransitionImage(
            from: pagedMediaVC,
            at: currentMediaVC.index
        )

        super.init()

        setupTransition()
    }

    // MARK: - Setup Methods

    private func setupTransition() {
        setupGestureRecognizer()
        setupViewHierarchy()
        setupInteractiveItem()
        setupAnimators()
        setupInitialState()
        beginTransitionIfNeeded()
    }

    private func setupGestureRecognizer() {
        panGestureRecognizer.addTarget(self, action: #selector(updateInteraction(_:)))
    }

    private func setupViewHierarchy() {
        let toViewController = transitionContext.viewController(forKey: .to)!
        let toView = toViewController.view!
        let containerView = transitionContext.containerView

        // Ensure the toView has the correct size and position
        toView.frame = transitionContext.finalFrame(for: toViewController)

        // Create tap stealing view to prevent user interaction during transition
        tapStealingView = UIView()
        tapStealingView.frame = containerView.bounds
        tapStealingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(tapStealingView)

        // Setup view hierarchy based on transition direction
        if transitionDirection == .presentation {
            toView.alpha = 0.0
            containerView.addSubview(toView)
        } else {
            containerView.insertSubview(toView, at: 0)
        }
    }

    private func setupInteractiveItem() {
        let containerView = transitionContext.containerView
        let initialFrame = initialFrameForCurrentTransitionItem()
        let targetFrame = containerView.convert(targetFrameForCurrentTransitionItem(), from: containerView)

        let item = PagedMediaTransitionItem(initialFrame: initialFrame)
        item.targetFrame = targetFrame
        item.mediaView = createTransitionMediaView(for: item, in: containerView)
        item.headerFooterViews = createHeaderFooterViews(in: containerView)

        self.interactiveItem = item
    }

    private func setupAnimators() {
        setupMainTransitionAnimator()
        setupHeaderFooterAnimator()
    }

    private func setupInitialState() {
        // Set initial alpha values
        if transitionDirection == .presentation {
            originalTransitionViews.fromView.alpha = 0
            currentMediaViewController.mediaView.alpha = 0
        } else {
            originalTransitionViews.toView.alpha = 0
        }

        pagedMediaViewController.headerViewContainer.alpha = 0
        pagedMediaViewController.footerViewContainer.alpha = 0

        // Hide animated controls
        currentMediaViewController.mediaView.animatedItemControlsView?.isHidden = true

        transitionContext.containerView.layoutIfNeeded()
    }

    private func beginTransitionIfNeeded() {
        if transitionContext.isInteractive {
            updateInteractiveItemFor(panGestureRecognizer.location(in: transitionContext.containerView))
        } else {
            animate(.end)
        }
    }

    // MARK: - Factory Methods

    private static func extractViewControllers(
        from context: UIViewControllerContextTransitioning,
        direction: PresentationDirection
    ) -> (PagedMediaViewController, MediaViewController) {
        let fromViewController = context.viewController(forKey: .from)!
        let toViewController = context.viewController(forKey: .to)!

        let pagedMediaVC: PagedMediaViewController

        if direction == .presentation {
            pagedMediaVC = toViewController as! PagedMediaViewController
        } else {
            pagedMediaVC = fromViewController as! PagedMediaViewController
        }

        let currentMediaVC = pagedMediaVC.currentViewController!
        return (pagedMediaVC, currentMediaVC)
    }

    private static func getOriginalView(
        from pagedMediaVC: PagedMediaViewController,
        at index: Int
    ) -> UIView {
        pagedMediaVC.pagedMediaDataSource!
            .pagedMediaViewController(pagedMediaVC, originalViewForItemAt: index)
    }

    private static func createTransitionViews(
        originalView: UIView,
        currentMediaViewController: MediaViewController,
        direction: PresentationDirection
    ) -> (fromView: UIView, toView: UIView) {
        if direction == .presentation {
            return (originalView, currentMediaViewController.view)
        } else {
            return (currentMediaViewController.mediaView, originalView)
        }
    }

    private static func getPresentationTransitionImage(
        from pagedMediaVC: PagedMediaViewController,
        at index: Int
    ) -> UIImage? {
        return pagedMediaVC.pagedMediaDataSource?
            .pagedMediaViewController(pagedMediaVC, transitionImageForItemAt: index)
    }

    private func createTransitionMediaView(for item: PagedMediaTransitionItem, in containerView: UIView) -> UIView {
        if transitionDirection == .presentation {
            let imageView = UIImageView(frame: containerView.convert(item.initialFrame, from: nil))
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.image = presentationTransitionImage
            containerView.addSubview(imageView)
            return imageView
        } else {
            let mediaView = currentMediaViewController.detachMediaView()
            mediaView.translatesAutoresizingMaskIntoConstraints = true
            containerView.addSubview(mediaView)
            mediaView.frame = containerView.convert(item.initialFrame, from: nil)
            return mediaView
        }
    }

    private func createHeaderFooterViews(in containerView: UIView) -> [UIView] {
        pagedMediaViewController.view.layoutIfNeeded()

        let headerImageView = UIImageView()
        let originalHeader = pagedMediaViewController.headerViewContainer
        headerImageView.image = originalHeader.snapshotImage()
        headerImageView.frame = containerView.convert(originalHeader.frame, from: pagedMediaViewController.view)
        containerView.addSubview(headerImageView)

        let footerImageView = UIImageView()
        let originalFooter = pagedMediaViewController.footerViewContainer
        footerImageView.image = originalFooter.snapshotImage()
        footerImageView.frame = containerView.convert(originalFooter.frame, from: pagedMediaViewController.view)
        containerView.addSubview(footerImageView)

        if transitionDirection == .presentation {
            headerImageView.alpha = 0
            footerImageView.alpha = 0
        }

        return [headerImageView, footerImageView]
    }

    // MARK: - Frame Calculation Methods

    private func initialFrameForCurrentTransitionItem() -> CGRect {
        if transitionDirection == .presentation {
            return originalTransitionViews.fromView.convert(originalTransitionViews.fromView.bounds, to: nil)
        } else {
            let view = originalTransitionViews.fromView
            let boundingRect = view.convert(view.bounds, to: nil)
            let aspectRatio = (view.bounds.size != .zero) ? view.bounds.size : presentationTransitionImage?.size
            assert(aspectRatio != nil, "aspectRatio must not be nil. This will result in unexpected transition animation.")
            return AVMakeRect(aspectRatio: aspectRatio ?? CGSize(width: 1, height: 1), insideRect: boundingRect)
        }
    }

    private func targetFrameForCurrentTransitionItem() -> CGRect {
        if transitionDirection == .presentation {
            guard let presentationController = pagedMediaViewController.presentationController as? PagedMediaPresentationController else {
                return .zero
            }

            let boundingRect = presentationController.frameOfPresentedViewInContainerView
            let view = originalTransitionViews.fromView
            let aspectRatio = presentationTransitionImage?.size ?? view.bounds.size
            assert(aspectRatio != .zero, "aspectRatio must not be zero. This will result in unexpected transition animation.")
            return AVMakeRect(aspectRatio: aspectRatio, insideRect: boundingRect)
        } else {
            return originalTransitionViews.toView.convert(originalTransitionViews.toView.bounds, to: nil)
        }
    }

    // MARK: - Animator Setup Methods

    private func setupMainTransitionAnimator() {
        let topView: UIView
        let topViewTargetAlpha: CGFloat

        if transitionDirection == .presentation {
            topView = transitionContext.viewController(forKey: .to)!.view!
            topViewTargetAlpha = 1.0
        } else {
            topView = transitionContext.viewController(forKey: .from)!.view!
            topViewTargetAlpha = 0.0
        }

        setupTransitionAnimator({
            topView.alpha = topViewTargetAlpha
        }, transitionCompletion: { [unowned self] (position) in
            self.handleTransitionCompletion(position: position)
        })
    }

    private func handleTransitionCompletion(position: UIViewAnimatingPosition) {
        // Reset all view's alpha and remove all transition views
        originalTransitionViews.fromView.alpha = 1
        originalTransitionViews.toView.alpha = 1
        currentMediaViewController.mediaView.alpha = 1
        pagedMediaViewController.headerViewContainer.alpha = 1
        pagedMediaViewController.footerViewContainer.alpha = 1
        currentMediaViewController.mediaView.animatedItemControlsView?.isHidden = false

        // Remove tap stealing view
        tapStealingView.removeFromSuperview()

        guard let interactiveItem else { return }

        interactiveItem.headerFooterViews.forEach { $0.removeFromSuperview() }

        if transitionDirection == .presentation {
            interactiveItem.mediaView?.removeFromSuperview()
        } else {
            if position == .end {
                interactiveItem.mediaView?.removeFromSuperview()
            } else if position == .start {
                currentMediaViewController.attachMediaView()
            }
        }
    }

    // MARK: - Interactive Transition Methods

    private func updateInteractiveItemFor(_ locationInContainer: CGPoint) {
        guard let itemCenter = interactiveItem?.mediaView?.center else { return }

        let offset = CGVector(dx: locationInContainer.x - itemCenter.x, dy: locationInContainer.y - itemCenter.y)
        interactiveItem?.touchOffset = offset
    }

    private func convert(_ velocity: CGPoint, for item: PagedMediaTransitionItem?) -> CGVector {
        guard let currentFrame = item?.mediaView?.frame, let targetFrame = item?.targetFrame else {
            return .zero
        }

        let dx = abs(targetFrame.midX - currentFrame.midX)
        let dy = abs(targetFrame.midY - currentFrame.midY)

        guard dx > 0 && dy > 0 else {
            return .zero
        }

        let range: CGFloat = 2
        let clippedVx = max(-range, min(range, velocity.x / dx))
        let clippedVy = max(-range, min(range, velocity.y / dy))
        return CGVector(dx: clippedVx, dy: clippedVy)
    }

    private func timingCurveVelocity() -> CGVector {
        let gestureVelocity = panGestureRecognizer.velocity(in: transitionContext.containerView)
        return convert(gestureVelocity, for: interactiveItem)
    }

    private func completionPosition() -> UIViewAnimatingPosition {
        let completionThreshold: CGFloat = 0.12
        let flickMagnitude: CGFloat = 1000
        let velocity = panGestureRecognizer.velocity(in: transitionContext.containerView)
        let velocityMagnitude = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        let isFlick = velocityMagnitude > flickMagnitude
        let isFlickDown = isFlick && (velocity.y > 0.0)
        let isFlickUp = isFlick && (velocity.y < 0.0)

        if (transitionDirection == .presentation && isFlickUp) || (transitionDirection == .dismissal && isFlickDown) {
            return .end
        } else if (transitionDirection == .presentation && isFlickDown) || (transitionDirection == .dismissal && isFlickUp) {
            return .start
        } else if transitionAnimator.fractionComplete > completionThreshold {
            return .end
        } else {
            return .start
        }
    }

    private func updateItemsForInteractive(translation: CGPoint) {
        guard let item = interactiveItem else { return }

        let progressStep = progressStepFor(translation: translation)
        let initialSize = item.initialFrame.size

        guard
            let mediaView = item.mediaView,
            mediaView.frame.origin.x.isFinite && mediaView.frame.origin.y.isFinite,
            let finalSize = item.targetFrame?.size
        else { return }

        let currentSize = mediaView.frame.size
        let sizeProgress = (currentSize.width - initialSize.width) / (finalSize.width - initialSize.width)
        let itemPercentComplete = max(-0.05, min(1.05, sizeProgress + progressStep))

        // Linear interpolation for item dimensions
        let itemWidth = initialSize.width + (finalSize.width - initialSize.width) * itemPercentComplete
        let itemHeight = initialSize.height + (finalSize.height - initialSize.height) * itemPercentComplete

        let scaleTransform = CGAffineTransform(scaleX: itemWidth / currentSize.width, y: itemHeight / currentSize.height)
        let scaledOffsetPoint = CGPoint(x: item.touchOffset.dx, y: item.touchOffset.dy).applying(scaleTransform)
        let scaledOffset = CGVector(dx: scaledOffsetPoint.x, dy: scaledOffsetPoint.y)

        let centerOffset = CGPoint(
            x: translation.x + item.touchOffset.dx - scaledOffset.dx,
            y: translation.y + item.touchOffset.dy - scaledOffset.dy
        )

        mediaView.center = CGPoint(
            x: mediaView.center.x + centerOffset.x,
            y: mediaView.center.y + centerOffset.y
        )
        mediaView.bounds = CGRect(origin: .zero, size: CGSize(width: itemWidth, height: itemHeight))
        item.touchOffset = CGVector(dx: scaledOffset.dx, dy: scaledOffset.dy)
    }

    private func progressStepFor(translation: CGPoint) -> CGFloat {
        (transitionDirection == .presentation ? -1.0 : 1.0) * translation.y / transitionContext.containerView.bounds.midY
    }

    // MARK: - UIViewPropertyAnimator Setup

    private func setupTransitionAnimator(_ transitionAnimations: @escaping ()->(),
                                         transitionCompletion: @escaping (UIViewAnimatingPosition)->()) {
        let transitionDuration = PagedMediaTransitionDriver.animationDuration

        transitionAnimator = UIViewPropertyAnimator(duration: transitionDuration, curve: .easeOut, animations: transitionAnimations)

        transitionAnimatorCompletion = { [unowned self] (position) in
            guard transitionAnimatorDidExecuteEndCompletion == false else { return }

            let completed = (position == .end)
            transitionAnimatorDidExecuteEndCompletion = completed
            transitionCompletion(position)
            self.transitionContext.completeTransition(completed)
        }

        transitionAnimator.addCompletion { [weak self] (position) in
            self?.transitionAnimatorCompletion?(position)
        }
    }

    private func setupHeaderFooterAnimator() {
        let headerFooterAnimator = Self.propertyAnimator(initialVelocity: timingCurveVelocity())
        headerFooterAnimator.addAnimations {
            guard let item = self.interactiveItem else { return }

            let targetAlpha: CGFloat = (self.transitionDirection == .presentation) ? 1 : 0
            item.headerFooterViews.forEach { $0.alpha = targetAlpha }
        }

        headerFooterAnimator.scrubsLinearly = false
        self.headerFooterAnimator = headerFooterAnimator
    }

    private func adjustedHeaderFooterPercentComplete(from transitionPercentComplete: CGFloat) -> CGFloat {
        // The header and footer should disappear/appear faster than the rest of the transitions
        min(1, transitionPercentComplete * 6)
    }

    private func headerFooterPresentationAnimationDelay() -> CGFloat {
        Self.animationDuration * 0.65
    }

    // MARK: - Gesture Handling

    @objc private func updateInteraction(_ fromGesture: UIPanGestureRecognizer) {
        switch fromGesture.state {
        case .began, .changed:
            handleOngoingInteraction(fromGesture)
        case .ended, .cancelled:
            endInteraction()
        default:
            break
        }
    }

    private func handleOngoingInteraction(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: transitionContext.containerView)
        let percentComplete = transitionAnimator.fractionComplete + progressStepFor(translation: translation)

        transitionAnimator.fractionComplete = percentComplete
        headerFooterAnimator.fractionComplete = adjustedHeaderFooterPercentComplete(from: percentComplete)
        transitionContext.updateInteractiveTransition(percentComplete)
        updateItemsForInteractive(translation: translation)
        gesture.setTranslation(CGPoint.zero, in: transitionContext.containerView)
    }

    func endInteraction() {
        guard transitionContext.isInteractive else { return }

        let completionPosition = self.completionPosition()
        if completionPosition == .end {
            transitionContext.finishInteractiveTransition()
        } else {
            transitionContext.cancelInteractiveTransition()
        }

        animate(completionPosition)
    }

    // MARK: - Animation Methods

    private func animate(_ toPosition: UIViewAnimatingPosition) {
        handleMediaItemPausing(for: toPosition)

        if shouldReplaceAnimatedMediaView(for: toPosition) {
            replaceAnimatedMediaViewWithSnapshotImageView()
        }

        animateItemFrames(to: toPosition)
        configureAndStartAnimators(for: toPosition)
    }

    private func handleMediaItemPausing(for position: UIViewAnimatingPosition) {
        let mediaItem = interactiveItem?.mediaView as? PagedMediaItem

        if transitionDirection == .dismissal && position == .end, let mediaItem = mediaItem {
            pagedMediaViewController.pagedMediaDelegate?.pagedMediaViewController(
                pagedMediaViewController,
                willDismissToOriginalViewAt: pagedMediaViewController.currentIndex,
                fromPagedMediaItem: mediaItem
            )
            mediaItem.paused = true
        }
    }

    private func shouldReplaceAnimatedMediaView(for position: UIViewAnimatingPosition) -> Bool {
        guard let mediaItem = interactiveItem?.mediaView as? PagedMediaItem else { return false }

        return transitionDirection == .dismissal && position == .end && mediaItem.isAnimated == true
    }

    private func animateItemFrames(to position: UIViewAnimatingPosition) {
        let itemFrameAnimator = Self.propertyAnimator(initialVelocity: timingCurveVelocity())
        itemFrameAnimator.addAnimations {
            guard let item = self.interactiveItem else { return }
            item.mediaView?.frame = (position == .end ? item.targetFrame : item.initialFrame)!
        }

        itemFrameAnimator.startAnimation()
        self.itemFrameAnimator = itemFrameAnimator
    }

    private func configureAndStartAnimators(for position: UIViewAnimatingPosition) {
        transitionAnimator.isReversed = (position == .start)
        headerFooterAnimator.isReversed = transitionAnimator.isReversed

        if transitionAnimator.state == .inactive {
            startInactiveAnimators()
        } else {
            continueActiveAnimators(for: position)
        }
    }

    private func startInactiveAnimators() {
        transitionAnimator.startAnimation()

        if transitionDirection == .presentation {
            headerFooterAnimator.startAnimation(afterDelay: headerFooterPresentationAnimationDelay())
        } else {
            headerFooterAnimator.fractionComplete = 0.1
        }

        headerFooterAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0.4)
    }

    private func continueActiveAnimators(for position: UIViewAnimatingPosition) {
        guard let itemFrameAnimator = itemFrameAnimator else { return }

        let durationFactor: CGFloat = itemFrameAnimator.duration
        transitionAnimator.continueAnimation(withTimingParameters: nil, durationFactor: durationFactor)
        headerFooterAnimator.continueAnimation(withTimingParameters: nil, durationFactor: durationFactor)

        if position == .end {
            // Workaround for UIViewPropertyAnimator bug where completion doesn't get called
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionAnimator.duration + 0.1) { [weak self] in
                self?.transitionAnimatorCompletion?(.end)
            }
        }
    }

    private func replaceAnimatedMediaViewWithSnapshotImageView() {
        guard
            let mediaItem = interactiveItem?.mediaView as? PagedMediaItem,
            mediaItem.isAnimated,
            let snapshotImage = mediaItem.animatedItemSnapshotAtCurrentTime
        else { return }

        let snapshotView = UIImageView(image: snapshotImage)
        snapshotView.frame = mediaItem.frame
        snapshotView.contentMode = .scaleAspectFit
        transitionContext.containerView.addSubview(snapshotView)
        interactiveItem?.mediaView = snapshotView
        mediaItem.removeFromSuperview()
    }

    // MARK: - Property Animator Factory

    private class func propertyAnimator(initialVelocity: CGVector = .zero,
                                        duration: TimeInterval = animationDuration) -> UIViewPropertyAnimator {
        let timingParameters = UISpringTimingParameters(dampingRatio: 0.9, initialVelocity: initialVelocity)
        return UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)
    }
}
