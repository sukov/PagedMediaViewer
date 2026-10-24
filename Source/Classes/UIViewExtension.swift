//
//  UIViewExtension.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//

import UIKit

extension UIView {
    func snapshotImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)

        return renderer.image { context in
            self.layer.render(in: context.cgContext)
        }
    }

    var owningViewController: UIViewController? {
        var responder: UIResponder? = next

        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }

            responder = current.next
        }

        return nil
    }
}
