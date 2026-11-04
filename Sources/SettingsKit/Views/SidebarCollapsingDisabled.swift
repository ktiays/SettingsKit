import AppKit
import SwiftUI

extension View {
    /// Keeps the enclosing split view's sidebar from collapsing, while leaving it resizable.
    ///
    /// Apply this modifier to the sidebar column of a `NavigationSplitView`. SwiftUI offers no
    /// public API for a sidebar that cannot collapse, so the modifier reaches the `NSSplitViewItem`
    /// that AppKit uses for the column and keeps its `canCollapse` property `false`. As a result,
    /// dragging the divider stops at the column's minimum width, and the Toggle Sidebar command
    /// is disabled.
    ///
    /// SwiftUI resets `canCollapse` whenever it updates the split view, so the modifier observes
    /// the property and restores it immediately. Pair the modifier with a column visibility that
    /// stays `.all`, so that SwiftUI does not collapse the column programmatically.
    func sidebarCollapsingDisabled() -> some View {
        background {
            NonCollapsibleSidebarAnchor()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

/// An invisible view that locates the split view item containing it and disables its collapsing.
private struct NonCollapsibleSidebarAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> NonCollapsibleSidebarAnchorView {
        NonCollapsibleSidebarAnchorView()
    }

    func updateNSView(_ nsView: NonCollapsibleSidebarAnchorView, context: Context) {
    }

    static func dismantleNSView(_ nsView: NonCollapsibleSidebarAnchorView, coordinator: ()) {
        nsView.releaseSplitViewItem()
    }
}

private final class NonCollapsibleSidebarAnchorView: NSView {
    private weak var splitViewItem: NSSplitViewItem?
    private var collapsibilityObservation: NSKeyValueObservation?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            releaseSplitViewItem()
            return
        }
        if !disableCollapsingOfEnclosingSplitViewItem() {
            // SwiftUI may finish installing the split view after the anchor joins the window.
            DispatchQueue.main.async { [weak self] in
                self?.disableCollapsingOfEnclosingSplitViewItem()
            }
        }
    }

    func releaseSplitViewItem() {
        collapsibilityObservation?.invalidate()
        collapsibilityObservation = nil
        splitViewItem = nil
    }

    /// Finds the split view item whose view contains this view and keeps it from collapsing.
    ///
    /// - Returns: `true` if the item was found.
    @discardableResult
    private func disableCollapsingOfEnclosingSplitViewItem() -> Bool {
        guard let item = enclosingSplitViewItem() else {
            return false
        }
        guard item !== splitViewItem else {
            return true
        }
        releaseSplitViewItem()
        splitViewItem = item
        item.canCollapse = false
        if item.isCollapsed {
            item.isCollapsed = false
        }
        collapsibilityObservation = item.observe(\.canCollapse) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.restoreNonCollapsibility()
            }
        }
        return true
    }

    private func restoreNonCollapsibility() {
        if let splitViewItem, splitViewItem.canCollapse {
            splitViewItem.canCollapse = false
        }
    }

    private func enclosingSplitViewItem() -> NSSplitViewItem? {
        var ancestor = superview
        while let view = ancestor {
            if
                let splitView = view as? NSSplitView,
                let controller = splitView.delegate as? NSSplitViewController,
                let item = controller.splitViewItems.first(where: {
                    $0.viewController.isViewLoaded && isDescendant(of: $0.viewController.view)
                })
            {
                return item
            }
            ancestor = view.superview
        }
        return nil
    }
}
