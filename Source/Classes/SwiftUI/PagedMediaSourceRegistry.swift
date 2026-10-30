//
//  PagedMediaSourceRegistry.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/08/2026.
//

import SwiftUI
import UIKit

@available(iOS 14.0, *)
@MainActor
final class PagedMediaSourceRegistry: ObservableObject {
    nonisolated static let coordinateSpaceName = "PagedMediaViewerContainer"

    @Published private(set) var hiddenID: AnyHashable?
    weak var containerView: UIView?

    // Kept after a lazy container discards the source view
    private var frames: [AnyHashable: CGRect] = [:]

    // MARK: - Recording

    func record(_ id: AnyHashable, frameInContainer: CGRect) {
        frames[id] = frameInContainer
    }

    func setHidden(_ hidden: Bool, for id: AnyHashable) {
        if hidden {
            hiddenID = id
        } else if hiddenID == id {
            hiddenID = nil
        }
    }

    // MARK: - Transition

    func source(for id: AnyHashable) -> PagedMediaSource? {
        guard let containerView, let frame = frames[id], frame.width > 0, frame.height > 0 else { return nil }

        return PagedMediaSource(frameInWindow: containerView.convert(frame, to: nil)) { [weak self] hidden in
            self?.setHidden(hidden, for: id)
        }
    }

    func fallbackSource() -> PagedMediaSource {
        guard let containerView else { return PagedMediaSource(frameInWindow: .zero) }

        let bounds = containerView.convert(containerView.bounds, to: nil)
        let side = min(bounds.width, bounds.height) / 3

        return PagedMediaSource(frameInWindow: CGRect(x: bounds.midX - side / 2,
                                                      y: bounds.midY - side / 2,
                                                      width: side,
                                                      height: side))
    }

    func transitionImage(for id: AnyHashable) -> UIImage? {
        guard
            let containerView,
            let host = containerView.owningViewController?.view,
            let frame = frames[id],
            frame.width > 0, frame.height > 0
        else { return nil }

        let rect = containerView.convert(frame, to: host)

        return UIGraphicsImageRenderer(size: rect.size).image { context in
            context.cgContext.translateBy(x: -rect.origin.x, y: -rect.origin.y)
            host.drawHierarchy(in: host.bounds, afterScreenUpdates: false)
        }
    }
}
