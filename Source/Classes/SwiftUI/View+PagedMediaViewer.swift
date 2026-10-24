//
//  View+PagedMediaViewer.swift
//  PagedMediaViewer
//
//  Created by Gorjan Shukov on 09/08/2026.
//

import SwiftUI
import UIKit

@available(iOS 14.0, *)
public extension View {
    /// Registers the view as the transition source of the item with the given `id`. Apply it to the displayed media rather than its cell, so the transition matches the media's frame.
    func pagedMediaSource<ID: Hashable>(id: ID) -> some View {
        modifier(PagedMediaSourceModifier(id: AnyHashable(id)))
    }

    /// Presents a `PagedMediaViewController` whenever `selection` points to one of the `items`.
    /// - Parameters:
    ///   - selection: Item to present. Set back to `nil` once the viewer dismisses.
    ///   - items: Items to page through, in the order they are displayed.
    ///   - recenter: Optional `scrollPosition(id:)` binding, updated while paging so sources in a lazy container stay laid out for the dismissal.
    ///   - presentationViewInsets: Insets on the viewer's presentation frame. Defaults to `.zero`.
    ///   - configure: Customization of the viewer, e.g. its header and footer containers.
    ///   - onIndexChange: Called after the transition to a new item is completed.
    ///   - transitionImage: Optional image for the item's transition. Defaults to a snapshot of the source, which is blank for video layers.
    ///   - onWillDismiss: Called just before the dismissal transition ends. Perfect time to sync the source with the media item.
    ///   - onDidDismiss: Called after the dismissal transition ends.
    ///   - mediaItem: Provides the media item view for the given item.
    func pagedMediaViewer<Item: Identifiable>(
        selection: Binding<Item.ID?>,
        items: [Item],
        recenter: Binding<Item.ID?>? = nil,
        presentationViewInsets: UIEdgeInsets = .zero,
        configure: ((PagedMediaViewController) -> Void)? = nil,
        onIndexChange: ((Int) -> Void)? = nil,
        transitionImage: ((Item) -> UIImage?)? = nil,
        onWillDismiss: ((Item, PagedMediaItem) -> Void)? = nil,
        onDidDismiss: ((Item) -> Void)? = nil,
        mediaItem: @escaping (Item) -> PagedMediaItem
    ) -> some View {
        modifier(PagedMediaViewerModifier(selection: selection,
                                          items: items,
                                          recenter: recenter,
                                          viewInsets: presentationViewInsets,
                                          configure: configure,
                                          onIndexChange: onIndexChange,
                                          transitionImage: transitionImage,
                                          onWillDismiss: onWillDismiss,
                                          onDidDismiss: onDidDismiss,
                                          mediaItem: mediaItem))
    }
}

// MARK: - Source

@available(iOS 14.0, *)
struct PagedMediaSourceModifier: ViewModifier {
    let id: AnyHashable

    @Environment(\.pagedMediaSourceRegistry) private var registry
    @Environment(\.pagedMediaHiddenID) private var hiddenID

    func body(content: Content) -> some View {
        let source = content.opacity(hiddenID == id ? 0 : 1)

        if #available(iOS 16.0, *) {
            source.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(PagedMediaSourceRegistry.coordinateSpaceName))
            } action: { frame in
                registry?.record(id, frameInContainer: frame)
            }
        } else {
            source.background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .named(PagedMediaSourceRegistry.coordinateSpaceName))

                    Color.clear
                        .onAppear { registry?.record(id, frameInContainer: frame) }
                        .onChange(of: frame) { registry?.record(id, frameInContainer: $0) }
                }
            )
        }
    }
}

// MARK: - Environment

@available(iOS 14.0, *)
private struct PagedMediaSourceRegistryKey: EnvironmentKey {
    static let defaultValue: PagedMediaSourceRegistry? = nil
}

private struct PagedMediaHiddenIDKey: EnvironmentKey {
    static let defaultValue: AnyHashable? = nil
}

extension EnvironmentValues {
    @available(iOS 14.0, *)
    var pagedMediaSourceRegistry: PagedMediaSourceRegistry? {
        get { self[PagedMediaSourceRegistryKey.self] }
        set { self[PagedMediaSourceRegistryKey.self] = newValue }
    }

    var pagedMediaHiddenID: AnyHashable? {
        get { self[PagedMediaHiddenIDKey.self] }
        set { self[PagedMediaHiddenIDKey.self] = newValue }
    }
}

// MARK: - Viewer

@available(iOS 14.0, *)
struct PagedMediaViewerModifier<Item: Identifiable>: ViewModifier {
    @Binding var selection: Item.ID?
    let items: [Item]
    let recenter: Binding<Item.ID?>?
    let viewInsets: UIEdgeInsets
    let configure: ((PagedMediaViewController) -> Void)?
    let onIndexChange: ((Int) -> Void)?
    let transitionImage: ((Item) -> UIImage?)?
    let onWillDismiss: ((Item, PagedMediaItem) -> Void)?
    let onDidDismiss: ((Item) -> Void)?
    let mediaItem: (Item) -> PagedMediaItem

    @StateObject private var registry = PagedMediaSourceRegistry()
    @StateObject private var presenter = PagedMediaPresenter<Item>()

    func body(content: Content) -> some View {
        presenter.registry = registry
        presenter.items = items
        presenter.recenter = recenter
        presenter.viewInsets = viewInsets
        presenter.configure = configure
        presenter.onIndexChange = onIndexChange
        presenter.transitionImage = transitionImage
        presenter.onWillDismiss = onWillDismiss
        presenter.onDidDismiss = onDidDismiss
        presenter.mediaItem = mediaItem
        presenter.onDismiss = { selection = nil }

        return content
            .coordinateSpace(name: PagedMediaSourceRegistry.coordinateSpaceName)
            .background(PagedMediaContainerProbe(registry: registry))
            .environment(\.pagedMediaSourceRegistry, registry)
            .environment(\.pagedMediaHiddenID, registry.hiddenID)
            .onChange(of: selection) { newValue in
                guard let id = newValue, let index = items.firstIndex(where: { $0.id == id }) else { return }

                presenter.present(at: index)
            }
    }
}

@available(iOS 14.0, *)
@MainActor
final class PagedMediaPresenter<Item: Identifiable>: NSObject, ObservableObject {
    var registry: PagedMediaSourceRegistry?
    var items: [Item] = []
    var recenter: Binding<Item.ID?>?
    var viewInsets: UIEdgeInsets = .zero
    var configure: ((PagedMediaViewController) -> Void)?
    var onIndexChange: ((Int) -> Void)?
    var transitionImage: ((Item) -> UIImage?)?
    var onWillDismiss: ((Item, PagedMediaItem) -> Void)?
    var onDidDismiss: ((Item) -> Void)?
    var mediaItem: ((Item) -> PagedMediaItem)?
    var onDismiss: (() -> Void)?

    private weak var presented: PagedMediaViewController?

    func present(at index: Int) {
        guard
            presented == nil,
            items.indices.contains(index),
            let registry,
            let presentingViewController = registry.containerView?.owningViewController
        else { return }

        let viewController = PagedMediaViewController(initialIndex: index)
        viewController.pagedMediaDataSource = self
        viewController.pagedMediaDelegate = self
        viewController.view.backgroundColor = .black
        configure?(viewController)
        presented = viewController
        presentingViewController.present(viewController, animated: true)
    }
}

// MARK: - PagedMediaDataSource

@available(iOS 14.0, *)
extension PagedMediaPresenter: PagedMediaDataSource {
    func numberOfItems(in pagedMediaViewController: PagedMediaViewController) -> Int {
        items.count
    }

    func presentationViewInsets(for pagedMediaViewController: PagedMediaViewController) -> UIEdgeInsets {
        viewInsets
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                  pagedMediaViewForItemAt index: Int) -> PagedMediaItem {
        mediaItem!(items[index])
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                  originalViewForItemAt index: Int) -> UIView {
        // Unused, `originalSourceForItemAt` takes precedence
        UIView()
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                  originalSourceForItemAt index: Int) -> PagedMediaSource {
        guard let registry, items.indices.contains(index) else { return PagedMediaSource(frameInWindow: .zero) }

        return registry.source(for: AnyHashable(items[index].id)) ?? registry.fallbackSource()
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                  transitionImageForItemAt index: Int) -> UIImage? {
        guard items.indices.contains(index) else { return nil }

        return transitionImage?(items[index]) ?? registry?.transitionImage(for: AnyHashable(items[index].id))
    }
}

// MARK: - PagedMediaDelegate

@available(iOS 14.0, *)
extension PagedMediaPresenter: PagedMediaDelegate {
    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, willTransitionTo index: Int) {
        guard items.indices.contains(index) else { return }

        // Keeps the source laid out in a lazy container for the dismissal
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            recenter?.wrappedValue = items[index].id
        }
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                  didTransitionTo toIndex: Int,
                                  fromIndex: Int) {
        onIndexChange?(toIndex)
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController,
                                  willDismissToOriginalViewAt index: Int,
                                  fromPagedMediaItem mediaItem: PagedMediaItem) {
        if items.indices.contains(index) {
            onWillDismiss?(items[index], mediaItem)
        }

        presented = nil
        onDismiss?()
    }

    func pagedMediaViewController(_ pagedMediaViewController: PagedMediaViewController, didDismissToOriginalViewAt index: Int) {
        guard items.indices.contains(index) else { return }

        onDidDismiss?(items[index])
    }
}

// MARK: - Container

@available(iOS 14.0, *)
struct PagedMediaContainerProbe: UIViewRepresentable {
    let registry: PagedMediaSourceRegistry

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.registry = registry

        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.registry = registry
    }

    final class ProbeView: UIView {
        weak var registry: PagedMediaSourceRegistry?

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if window != nil {
                registry?.containerView = self
            }
        }
    }
}
