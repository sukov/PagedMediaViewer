# PagedMediaViewer

[![Version](https://img.shields.io/cocoapods/v/PagedMediaViewer.svg?style=flat)](https://cocoapods.org/pods/PagedMediaViewer)
[![License](https://img.shields.io/cocoapods/l/PagedMediaViewer.svg?style=flat)](https://cocoapods.org/pods/PagedMediaViewer)
[![Language Swift](https://img.shields.io/badge/Language-Swift%205.0-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/cocoapods/p/PagedMediaViewer.svg?style=flat)](https://cocoapods.org/pods/PagedMediaViewer)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](https://www.swift.org/package-manager)

## Features

PagedMediaViewer is an elegant media display library, comparable to native Photos app, supporting both images and videos.

  - [x] Features smooth transition effects when expanding from thumbnail to fullscreen mode, with seamless return animation to the original position upon closure.
  - [x] Supports any custom media view which conforms to `PagedMediaItem`, allowing for flexible integration of various media types.
  - [x] Completely configurable header, footer, and playback controls.
  - [x] Optimized zoom functionality with automatic UI elements hiding during zoom interactions.
  - [x] Offers adjustable presentation view insets to ensure fullscreen transitions do not overlap with other UI elements (e.g. promotional content).
  - [x] [Complete Documentation](https://sukov.github.io/PagedMediaViewer/)

## Demo

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Usage 

Check [PagedMediaViewControllerExample.swift](Example/PagedMediaViewer/PagedMediaViewControllerExample.swift) `PagedMediaDataSource` and `PagedMediaDelegate` implementation from the Example project.


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
