//
//  PagedMediaTransitionController.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//


import UIKit

enum PresentationDirection {
    case presentation
    case dismissal
    case none
}

final class PagedMediaPresentationController: UIPresentationController {
    override var shouldRemovePresentersView: Bool {
        // We need the view to remain only on presentation in order for the `presentationViewInsets` to be respected.
        // On the other hand, it has to be removed when dismissing to prevent black screen on transition end.
        presentedViewController.isBeingDismissed
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        guard
            let insets = (presentedViewController as? PagedMediaViewController)?.presentationViewInsets,
            insets != .zero
        else {
            return containerView.frame
        }

        return CGRect(x: insets.left,
                      y: insets.top,
                      width: containerView.bounds.width - insets.left - insets.right,
                      height: containerView.bounds.height - insets.top - insets.bottom)
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()

        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

final class PagedMediaTransitionController: NSObject {
    static let transitionDuration: TimeInterval = 0.3

    private var panGestureRecognizer = UIPanGestureRecognizer()
    private var transitionDriver: PagedMediaTransitionDriver?
    private var presentationDirection: PresentationDirection = .none
    private var initiallyInteractive = false
    private weak var presentationController: PagedMediaPresentationController?

    override init() {
        super.init()

        configurePanGestureRecognizer()
    }

    private func configurePanGestureRecognizer() {
        panGestureRecognizer.delegate = self
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.addTarget(self, action: #selector(initiateTransitionInteractively(_:)))
    }

    @objc private func initiateTransitionInteractively(_ panGesture: UIPanGestureRecognizer) {
        if panGesture.state == .began {
            initiallyInteractive = true
            presentationController?.presentedViewController.dismiss(animated: true)
        }

        if panGesture.state == .ended && transitionDriver == nil {
            // Edge case where the pan gesture begins and ends before `startInteractiveTransition(_:)` gets called.
            initiallyInteractive = false
        }
    }
}

// MARK: UIGestureRecognizerDelegate

extension PagedMediaTransitionController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else { return true }
        guard
            let scrollView = otherGestureRecognizer.view as? UIScrollView,
            scrollView.tag == MediaViewController.scrollViewTag
        else { return false }

        // If it is MediaViewController's UIScrollView, allow panning only if its content is at the very top
        if (scrollView.contentOffset.y + scrollView.contentInset.top) == 0 {
            return true
        }

        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let transitionDriver = self.transitionDriver else {
            let translation = panGestureRecognizer.translation(in: panGestureRecognizer.view)
            let translationIsVertical = (translation.y > 0) && (abs(translation.y) > abs(translation.x))
            return translationIsVertical
        }

        return transitionDriver.isInteractive
    }
}

// MARK: UIViewControllerInteractiveTransitioning

extension PagedMediaTransitionController: UIViewControllerInteractiveTransitioning {
    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        transitionDriver = PagedMediaTransitionDriver(transitionDirection: presentationDirection,
                                                      context: transitionContext,
                                                      panGestureRecognizer: panGestureRecognizer)

        if initiallyInteractive == false {
            // Fixes transition view stays forever on screen making the app unresponsive.
            // Edge case where the pan gesture begins and ends before `transitionDriver` is set.
            transitionDriver?.endInteraction()
        }
    }

    var wantsInteractiveStart: Bool {
        initiallyInteractive
    }
}

// MARK: UIViewControllerAnimatedTransitioning

extension PagedMediaTransitionController: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        Self.transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        transitionDriver = PagedMediaTransitionDriver(transitionDirection: presentationDirection,
                                                      context: transitionContext,
                                                      panGestureRecognizer: panGestureRecognizer)
    }

    func animationEnded(_ transitionCompleted: Bool) {
        // Clean up our helper object and any additional state
        transitionDriver = nil
        initiallyInteractive = false
        presentationDirection = .none
    }
}

// MARK: UIViewControllerTransitioningDelegate

extension PagedMediaTransitionController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        let presentationController = PagedMediaPresentationController(
            presentedViewController: presented,
            presenting: presenting)
        self.presentationController = presentationController
        presentationController.presentedView?.addGestureRecognizer(panGestureRecognizer)

        return presentationController
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentationDirection = .presentation
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentationDirection = .dismissal
        return self
    }

    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        initiallyInteractive ? self : nil
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        initiallyInteractive ? self : nil
    }
}
