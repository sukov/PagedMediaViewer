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
    /// Hides the item while the transition animates it and reveals it once done.
    public let setHidden: (Bool) -> Void

    /// Initializes the source with the item's frame in window coordinates and an optional visibility handler.
    public init(frameInWindow: CGRect, setHidden: @escaping (Bool) -> Void = { _ in }) {
        self.frameInWindow = frameInWindow
        self.setHidden = setHidden
    }

    /// Initializes the source from a view, using its frame in window coordinates and toggling its alpha.
    public init(view: UIView) {
        self.init(frameInWindow: view.convert(view.bounds, to: nil)) { hidden in
            view.alpha = hidden ? 0 : 1
        }
    }
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

    func setHidden(_ hidden: Bool) {
        switch self {
        case .source(let source):
            source.setHidden(hidden)
        case .view(let view):
            view.alpha = hidden ? 0 : 1
        }
    }
}
