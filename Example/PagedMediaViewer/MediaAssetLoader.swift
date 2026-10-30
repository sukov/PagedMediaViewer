//
//  MediaAssetLoader.swift
//  PagedMediaViewer_Example
//
//  Created by Gorjan Shukov on 09/08/2026.
//

import Photos
import AVFoundation
import UIKit

/// Shared Photo Library access, so thumbnails and fullscreen items reuse the same image cache and video assets.
@MainActor
final class MediaAssetLoader {
    static let shared = MediaAssetLoader()

    let imageManager = PHCachingImageManager()

    private var avAssets: [String: AVAsset] = [:]
    private var pendingCompletions: [String: [(AVAsset?) -> Void]] = [:]

    // MARK: - Images

    /// Requests an image, delivering a degraded version first and the high quality one after.
    @discardableResult
    func requestImage(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
            guard let image else { return }

            if Thread.isMainThread {
                completion(image)
            } else {
                DispatchQueue.main.async { completion(image) }
            }
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    func startCachingImages(for assets: [PHAsset], targetSize: CGSize) {
        guard targetSize != .zero else { return }

        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFit, options: nil)
    }

    func stopCachingImages(for assets: [PHAsset], targetSize: CGSize) {
        guard targetSize != .zero else { return }

        imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFit, options: nil)
    }

    // MARK: - Videos

    /// Loads the full quality video asset. Completes synchronously when already loaded.
    func loadAVAsset(for asset: PHAsset, completion: @escaping (AVAsset?) -> Void) {
        let id = asset.localIdentifier

        if let cached = avAssets[id] {
            completion(cached)

            return
        }

        // Coalesce concurrent requests, e.g. from the thumbnail and the fullscreen item
        if pendingCompletions[id] != nil {
            pendingCompletions[id]?.append(completion)

            return
        }

        pendingCompletions[id] = [completion]

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        imageManager.requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }

                if let avAsset {
                    self.avAssets[id] = avAsset
                }

                self.pendingCompletions.removeValue(forKey: id)?.forEach { $0(avAsset) }
            }
        }
    }

    func prefetchVideos(in assets: [PHAsset]) {
        for asset in assets where asset.mediaType == .video {
            loadAVAsset(for: asset) { _ in }
        }
    }
}
