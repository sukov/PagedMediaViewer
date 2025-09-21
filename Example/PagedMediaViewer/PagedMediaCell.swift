//
//  PagedMediaCell.swift
//  PagedMediaViewer_Example
//
//  Created by Gorjan Shukov on 16.9.25.
//


import UIKit
import Photos

class PagedMediaCell: UICollectionViewCell {
    let mediaView: MediaView

    override init(frame: CGRect) {
        mediaView = MediaView(frame: CGRect(origin: CGPoint.zero, size: frame.size))
        mediaView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        super.init(frame: frame)

        backgroundView = mediaView
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with asset: PHAsset) {
        mediaView.configure(asset: asset, targetSize: bounds.size)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        mediaView.pauseVideo() // Pause any playing video
        // MediaView will handle its own cleanup
    }
}
