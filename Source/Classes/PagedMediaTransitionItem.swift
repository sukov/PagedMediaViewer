//
//  PagedMediaTransitionItem.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//

import UIKit

class PagedMediaTransitionItem: NSObject {
    var initialFrame: CGRect
    var targetFrame: CGRect?
    var mediaView: UIView?
    var headerFooterViews: [UIView] = []
    var touchOffset: CGVector = .zero
    
    init(initialFrame: CGRect) {
        self.initialFrame = initialFrame
        super.init()
    }
}
