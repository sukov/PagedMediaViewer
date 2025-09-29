# PagedMediaViewer

[![Version](https://img.shields.io/cocoapods/v/PagedMediaViewer.svg?style=flat)](https://cocoapods.org/pods/PagedMediaViewer)
[![License](https://img.shields.io/cocoapods/l/PagedMediaViewer.svg?style=flat)](https://cocoapods.org/pods/PagedMediaViewer)
[![Language Swift](https://img.shields.io/badge/Language-Swift%205.0-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/cocoapods/p/PagedMediaViewer.svg?style=flat)](https://cocoapods.org/pods/PagedMediaViewer)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](https://www.swift.org/package-manager)

## Features

PagedMediaViewer is an elegant media display library, comparable to native Photos app, supporting both images and videos.

  - [x] Smooth thumbnail-to-fullscreen interactive transition with return animation
  - [x] Fullscreen display of any custom (media) view conforming to `PagedMediaItem` protocol
  - [x] Configurable header, footer, and playback controls
  - [x] Double tap & pinch to zoom with auto-hiding UI elements
  - [x] Adjustable presentation insets to allow underlying views to remain visible (e.g. promotional content)
  - [x] Comprehensive Unit Test Coverage
  - [x] [Complete Documentation](https://sukov.github.io/PagedMediaViewer/)

## Demo

| Image transition | Video transition & zoom | Media items pagination |
|:---:|:---:|:---:|
|![1](https://github.com/user-attachments/assets/233f6227-7f1e-425a-8709-d6489281f35d)|![2](https://github.com/user-attachments/assets/936afb3a-9b76-4350-87ee-2d41106a350c)|![3](https://github.com/user-attachments/assets/2615ed42-f788-437a-8d5e-920a51597f02)|

The previews are from the example project. To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Usage 

### Quick Start

Check [PagedMediaViewControllerExample.swift](Example/PagedMediaViewer/PagedMediaViewControllerExample.swift) `PagedMediaDataSource` and `PagedMediaDelegate` implementation from the Example project.

### PagedMediaItem protocol

Media item to be presented in the PagedMediaViewController.

```Swift
public protocol PagedMediaItem: UIView {
    /// Updates paused state depending on the transition status.
    var paused: Bool { get set }
    /// Whether the item is animated (video, gif, etc) or static (image, etc).
    var isAnimated: Bool { get }
    /// Used in the last part of the dismissal transition for animated items (if not `nil`) for smooth effect. Defaults to `nil`.
    var animatedItemSnapshotAtCurrentTime: UIImage? { get }
    /// Controls for play/pause and scrubbing.  Defaults to `nil`.
    var animatedItemControlsView: UIView? { get }
}
```

### PagedMediaDataSource protocol

Conform to `PagedMediaDataSource` to provide media items and customize their presentation.

```Swift
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
```

### PagedMediaDelegate protocol

Optional: Conform to `PagedMediaDelegate` for transition and item change events.

```Swift
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
```

## Requirements

- iOS 13.0+
- Xcode 12.0+
- Swift 5.0+


## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate PagedMediaViewer into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '13.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'PagedMediaViewer'
end
```

Then, run the following command:

```bash
$ pod install
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. 

Once you have your Swift package set up, adding `PagedMediaViewer` as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/sukov/PagedMediaViewer.git", from: "1.0.0")
]
```

## Author

sukov, gorjan.shukov@gmail.com

## License

PagedMediaViewer is available under the MIT license. See the LICENSE file for more info.
