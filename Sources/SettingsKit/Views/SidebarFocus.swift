import AppKit
import SwiftUI

extension View {
    /// Gives the enclosing sidebar list the keyboard focus that the system settings sidebar has.
    ///
    /// Apply this modifier to the list in the sidebar column. The list receives the focus when its
    /// window is shown and whenever the user clicks in it, so that its selection shows in the
    /// accent color, and the arrow keys move between sections.
    ///
    /// Without the modifier, neither happens. When the window is shown, AppKit focuses the first
    /// text field of the page instead. A click on a row is handled by the row's SwiftUI content,
    /// which changes the selection without making the list the first responder; only a click on
    /// an empty area of the list reaches the list itself.
    func sidebarFocusBehavior() -> some View {
        background {
            SidebarFocusAnchor()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

/// An invisible view that finds the sidebar list next to it and manages that list's focus.
private struct SidebarFocusAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> SidebarFocusAnchorView {
        SidebarFocusAnchorView()
    }

    func updateNSView(_ nsView: SidebarFocusAnchorView, context: Context) {
    }

    static func dismantleNSView(_ nsView: SidebarFocusAnchorView, coordinator: ()) {
        nsView.stopManagingFocus()
    }
}

private final class SidebarFocusAnchorView: NSView {
    private weak var cachedList: NSOutlineView?
    private var mouseDownMonitor: Any?
    private var occlusionObserver: (any NSObjectProtocol)?
    private var isWindowShown = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopManagingFocus()
        guard let window else {
            return
        }
        startManagingFocus(in: window)
    }

    private func startManagingFocus(in window: NSWindow) {
        isWindowShown = window.isVisible
        if isWindowShown {
            // A window that is already shown, such as one that embeds the settings view, focuses
            // the list now, unless another view has the focus.
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else {
                    return
                }
                if window.firstResponder == nil || window.firstResponder === window, let list = self.sidebarList() {
                    window.makeFirstResponder(list)
                }
            }
        }
        // The occlusion state changes when the window is shown, including when a closed window is
        // shown again, and also when other windows cover or uncover it. Only the transition from
        // hidden to shown moves the focus, so switching back to the window keeps its focus.
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.windowOcclusionDidChange()
            }
        }
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.focusList(for: event)
            }
            return event
        }
    }

    func stopManagingFocus() {
        if let mouseDownMonitor {
            NSEvent.removeMonitor(mouseDownMonitor)
        }
        mouseDownMonitor = nil
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        occlusionObserver = nil
        cachedList = nil
    }

    /// Focuses the list when the window goes from hidden to shown, replacing the text field that
    /// AppKit focuses at that moment.
    private func windowOcclusionDidChange() {
        guard let window else {
            return
        }
        let isShown = window.isVisible
        defer {
            isWindowShown = isShown
        }
        guard isShown, !isWindowShown, let list = sidebarList() else {
            return
        }
        window.makeFirstResponder(list)
    }

    /// Makes the list the first responder before a click in it is handled.
    private func focusList(for event: NSEvent) {
        guard
            let window,
            event.window === window,
            let list = sidebarList(),
            window.firstResponder !== list,
            list.visibleRect.contains(list.convert(event.locationInWindow, from: nil))
        else {
            return
        }
        window.makeFirstResponder(list)
    }

    /// The list of the sidebar column the modifier is applied to.
    private func sidebarList() -> NSOutlineView? {
        if let cachedList, cachedList.window === window {
            return cachedList
        }
        cachedList = enclosingSidebarList()
        return cachedList
    }

    /// The nearest list around this view, which is the sidebar's list rather than a list in the
    /// detail column. SwiftUI may install the list after this view, so the search runs when the
    /// list is needed.
    private func enclosingSidebarList() -> NSOutlineView? {
        var ancestor = superview
        // The search stops below the split view, which also contains the detail column.
        while let view = ancestor, !(view is NSSplitView) {
            if let list = Self.firstOutlineView(in: view) {
                return list
            }
            ancestor = view.superview
        }
        return nil
    }

    private static func firstOutlineView(in view: NSView) -> NSOutlineView? {
        if let list = view as? NSOutlineView {
            return list
        }
        for subview in view.subviews {
            if let list = firstOutlineView(in: subview) {
                return list
            }
        }
        return nil
    }
}
