//
//  PagedMediaSource.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/08/2026.
//

import UIKit

/// Original position of a media item, used by the presentation and dismissal transitions.
@MainActor
public struct PagedMediaSource {
    /// Frame of the item in window coordinates.
    public let frameInWindow: CGRect
    /// Corner radius the item is displayed with. The transition rounds the media to it at the source end. Defaults to `0`.
    public let cornerRadius: CGFloat
    /// Corners `cornerRadius` applies to. Defaults to all corners.
    public let maskedCorners: CACornerMask
    /// How the item fills its frame. `.scaleAspectFill` keeps a cropped thumbnail cropped at the source end of the transition. Defaults to `.scaleAspectFit`.
    public let contentMode: UIView.ContentMode
    /// Hides the item while the transition animates it and reveals it once done.
    public let setHidden: (Bool) -> Void

    /// Initializes the source with the item's frame in window coordinates, its shape and an optional visibility handler.
    public init(frameInWindow: CGRect,
                cornerRadius: CGFloat = 0,
                maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
                contentMode: UIView.ContentMode = .scaleAspectFit,
                setHidden: @escaping (Bool) -> Void = { _ in }) {
        self.frameInWindow = frameInWindow
        self.cornerRadius = cornerRadius
        self.maskedCorners = maskedCorners
        self.contentMode = contentMode
        self.setHidden = setHidden
    }

    /// Initializes the source from a view, using its frame in window coordinates, its layer's corners and content mode, and toggling its alpha.
    public init(view: UIView) {
        self.init(frameInWindow: view.convert(view.bounds, to: nil),
                  cornerRadius: view.layer.cornerRadius,
                  maskedCorners: view.layer.maskedCorners,
                  contentMode: view.contentMode == .scaleAspectFill ? .scaleAspectFill : .scaleAspectFit) { hidden in
            view.alpha = hidden ? 0 : 1
        }
    }
}

extension CACornerMask {
    static let allCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
}

@MainActor
enum PagedMediaTransitionEndpoint {
    case source(PagedMediaSource)
    case view(UIView)

    var frameInWindow: CGRect {
        switch self {
        case .source(let source):
            return source.frameInWindow
        case .view(let view):
            return view.convert(view.bounds, to: nil)
        }
    }

    var aspectSize: CGSize {
        switch self {
        case .source(let source):
            return source.frameInWindow.size
        case .view(let view):
            return view.bounds.size
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .source(let source):
            return source.cornerRadius
        case .view:
            return 0
        }
    }

    var maskedCorners: CACornerMask {
        switch self {
        case .source(let source):
            return source.maskedCorners
        case .view:
            return .allCorners
        }
    }

    func setHidden(_ hidden: Bool) {
        switch self {
        case .source(let source):
            source.setHidden(hidden)
        case .view(let view):
            view.alpha = hidden ? 0 : 1
        }
    }
}
