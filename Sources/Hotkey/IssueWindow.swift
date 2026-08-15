import AppKit
import HotkeyCore
import SwiftUI

final class IssueWindowController: NSWindowController {
    init(issueCenter: IssueCenter) {
        let rootView = IssueListView(issueCenter: issueCenter)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Hotkey Errors"
        window.setContentSize(NSSize(width: 560, height: 360))
        window.minSize = NSSize(width: 460, height: 280)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct IssueListView: View {
    @ObservedObject var issueCenter: IssueCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hotkey Errors")
                .font(.title2.weight(.semibold))
                .padding()
            Divider()
            if issueCenter.issues.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("No unresolved errors")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(issueCenter.issues) { issue in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(issue.kind.title, systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                            Spacer()
                            Text(issue.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let applicationName = issue.applicationName {
                            Text(applicationName)
                                .font(.subheadline.weight(.medium))
                        }
                        Text(issue.reason)
                        Text("Suggested correction: \(issue.suggestion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}
