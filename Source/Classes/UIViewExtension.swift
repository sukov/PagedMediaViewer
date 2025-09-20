//
//  UIViewExtension.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/15/2025.
//

extension UIView {
    func snapshotImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)

        return renderer.image { context in
            self.layer.render(in: context.cgContext)
        }
    }
}
