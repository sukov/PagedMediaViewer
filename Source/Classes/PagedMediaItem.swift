//
//  PagedMediaItem.swift
//  Pods
//
//  Created by Gorjan Shukov on 20.9.25.
//

/// Media item to be presented in the PagedMediaViewController.
public protocol PagedMediaItem: UIView {
    /// Updates paused state depending on the transition status.
    var paused: Bool { get set }
    /// Whether the item is animated (video, gif, etc) or static (image, etc).
    var isAnimated: Bool { get }
    /// Used in the last part of the dismissal transition for animated items if not nil.
    var animatedItemSnapshotAtCurrentTime: UIImage? { get }
    /// Controls for play/pause and scrubbing
    var animatedItemControlsView: UIView? { get }
}

public extension PagedMediaItem {
    var animatedItemSnapshotAtCurrentTime: UIImage? { self.snapshotImage() }
    var animatedItemControlsView: UIView? { nil }
}
