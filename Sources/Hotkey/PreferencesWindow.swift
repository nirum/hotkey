import AppKit
import Combine
import HotkeyCore
import SwiftUI
import UniformTypeIdentifiers

struct BindingEditorDraft: Identifiable, Equatable {
    let id: UUID
    var target: AppTarget?
    var keyCode: UInt32?
    var modifiers: ShortcutModifiers
    let isNew: Bool

    init(binding: HotkeyBinding? = nil) {
        id = binding?.id ?? UUID()
        target = binding?.target
        keyCode = binding?.keyCode
        modifiers = binding?.modifiers ?? .option
        isNew = binding == nil
    }
}

final class PreferencesViewModel: ObservableObject {
    @Published private(set) var bindings: [HotkeyBinding]
    @Published var editor: BindingEditorDraft?
    @Published var selection: UUID?

    let issueCenter: IssueCenter
    private let coordinator: RegistrationCoordinator

    init(coordinator: RegistrationCoordinator, issueCenter: IssueCenter) {
        self.coordinator = coordinator
        self.issueCenter = issueCenter
        bindings = coordinator.activeBindings
    }

    func synchronize() {
        bindings = coordinator.activeBindings
    }

    func add() {
        editor = BindingEditorDraft()
    }

    func edit(_ id: UUID) {
        guard let binding = bindings.first(where: { $0.id == id }) else { return }
        editor = BindingEditorDraft(binding: binding)
    }

    func save(_ draft: BindingEditorDraft) -> String? {
        guard let target = draft.target else {
            return "Choose an application bundle (.app)."
        }
        guard case .accepted(let recorded) = ShortcutInterpreter.capture(
            keyCode: draft.keyCode,
            modifiers: draft.modifiers
        ) else {
            return shortcutError(keyCode: draft.keyCode, modifiers: draft.modifiers)
        }

        let binding = HotkeyBinding(
            id: draft.id,
            target: target,
            keyCode: recorded.keyCode,
            modifiers: recorded.modifiers
        )
        var proposed = bindings
        if let index = proposed.firstIndex(where: { $0.id == draft.id }) {
            proposed[index] = binding
        } else {
            proposed.append(binding)
        }

        guard coordinator.apply(proposed) == .applied else {
            return issueCenter.issues.first(where: {
                $0.bindingID == draft.id || $0.bindingID == nil
            })?.reason ?? "The shortcut could not be applied."
        }
        bindings = coordinator.activeBindings
        editor = nil
        return nil
    }

    func remove(_ id: UUID) {
        let proposed = bindings.filter { $0.id != id }
        if coordinator.apply(proposed) == .applied {
            bindings = coordinator.activeBindings
        }
    }

    private func shortcutError(
        keyCode: UInt32?,
        modifiers: ShortcutModifiers
    ) -> String {
        if case .rejected(let message) = ShortcutInterpreter.capture(
            keyCode: keyCode,
            modifiers: modifiers
        ) {
            return message
        }
        return "Choose a valid shortcut."
    }
}

final class PreferencesWindowController: NSWindowController {
    private let viewModel: PreferencesViewModel

    init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
        super.init(window: nil)

        let view = PreferencesView(model: viewModel)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Hotkey Preferences"
        window.setContentSize(NSSize(width: 660, height: 440))
        window.minSize = NSSize(width: 560, height: 360)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        self.window = window
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        viewModel.synchronize()
        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct PreferencesView: View {
    @ObservedObject var model: PreferencesViewModel
    @ObservedObject private var issues: IssueCenter

    init(model: PreferencesViewModel) {
        self.model = model
        issues = model.issueCenter
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    model.add()
                } label: {
                    Label("Add Shortcut", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if model.bindings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("No shortcuts configured")
                        .font(.headline)
                    Text("Add a shortcut to toggle an application from anywhere.")
                        .foregroundStyle(.secondary)
                    Button("Add Shortcut") { model.add() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { model.selection },
                    set: { model.selection = $0 }
                )) {
                    ForEach(model.bindings) { binding in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(nsImage: applicationIcon(for: binding.target.applicationURL))
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                Text(binding.target.displayName)
                                Spacer()
                                Text(ShortcutDisplay.string(
                                    keyCode: binding.keyCode,
                                    modifiers: binding.modifiers
                                ))
                                .font(.system(.body, design: .rounded).weight(.medium))
                            }
                            ForEach(issues.issues.filter { $0.bindingID == binding.id }) { issue in
                                Text(issue.reason)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .tag(binding.id)
                    }
                }

                Divider()
                HStack {
                    Button {
                        if let selection = model.selection { model.edit(selection) }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(model.selection == nil)

                    Button(role: .destructive) {
                        if let selection = model.selection {
                            model.remove(selection)
                            model.selection = nil
                        }
                    } label: {
                        Label("Remove", systemImage: "minus")
                    }
                    .disabled(model.selection == nil)
                    Spacer()
                }
                .padding(12)
            }
        }
        .sheet(item: $model.editor) { draft in
            BindingEditorView(draft: draft) { updated in
                model.save(updated)
            } onCancel: {
                model.editor = nil
            }
        }
    }

    private func applicationIcon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

private struct BindingEditorView: View {
    @ObservedObject private var state: BindingEditorState

    let onSave: (BindingEditorDraft) -> String?
    let onCancel: () -> Void

    init(
        draft: BindingEditorDraft,
        onSave: @escaping (BindingEditorDraft) -> String?,
        onCancel: @escaping () -> Void
    ) {
        _state = ObservedObject(wrappedValue: BindingEditorState(draft: draft))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(state.draft.isNew ? "Add Shortcut" : "Edit Shortcut")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Application")
                    .font(.headline)
                Button {
                    state.choosingApplication = true
                } label: {
                    HStack {
                        if let target = state.draft.target {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: target.applicationURL.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            Text(target.displayName)
                        } else {
                            Image(systemName: "app.badge")
                            Text("Choose Application…")
                        }
                        Spacer()
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Keyboard Shortcut")
                    .font(.headline)
                ShortcutRecorder(
                    keyCode: state.draft.keyCode,
                    modifiers: state.draft.modifiers
                ) { shortcut in
                    state.draft.keyCode = shortcut.keyCode
                    state.draft.modifiers = shortcut.modifiers
                    state.errorMessage = nil
                } onError: { errorMessage in
                    state.errorMessage = errorMessage
                }
                .frame(height: 38)
                Text("Use Command, Option, or Control. Shift may be added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = state.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    state.errorMessage = onSave(state.draft)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 430)
        .fileImporter(
            isPresented: Binding(
                get: { state.choosingApplication },
                set: { state.choosingApplication = $0 }
            ),
            allowedContentTypes: [.applicationBundle],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first,
                      url.pathExtension.lowercased() == "app" else {
                    state.errorMessage = "Choose a macOS application bundle (.app)."
                    return
                }
                let bundle = Bundle(url: url)
                let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                state.draft.target = AppTarget(
                    displayName: name,
                    bundleIdentifier: bundle?.bundleIdentifier,
                    applicationURL: url
                )
                state.errorMessage = nil
            case .failure(let error):
                state.errorMessage = "The application could not be selected: \(error.localizedDescription)"
            }
        }
    }
}

private final class BindingEditorState: ObservableObject {
    @Published var draft: BindingEditorDraft
    @Published var choosingApplication = false
    @Published var errorMessage: String?

    init(draft: BindingEditorDraft) {
        self.draft = draft
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let keyCode: UInt32?
    let modifiers: ShortcutModifiers
    let onAccepted: (RecordedShortcut) -> Void
    let onError: (String) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField(keyCode: keyCode, modifiers: modifiers)
        field.onAccepted = onAccepted
        field.onError = onError
        return field
    }

    func updateNSView(_ field: ShortcutRecorderField, context: Context) {
        field.onAccepted = onAccepted
        field.onError = onError
        field.synchronize(keyCode: keyCode, modifiers: modifiers)
    }
}

private final class ShortcutRecorderField: NSTextField {
    var onAccepted: ((RecordedShortcut) -> Void)?
    var onError: ((String) -> Void)?

    private var reducer: ShortcutRecordingReducer

    override var acceptsFirstResponder: Bool { true }

    init(keyCode: UInt32?, modifiers: ShortcutModifiers) {
        reducer = ShortcutRecordingReducer(keyCode: keyCode, modifiers: modifiers)
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        alignment = .center
        font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        bezelStyle = .roundedBezel
        focusRingType = .default
        refreshDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        reducer.reduce(.begin)
        refreshDisplay()
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        reducer.reduce(.focusLost)
        refreshDisplay()
        return true
    }

    override func keyDown(with event: NSEvent) {
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        capture(event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        reducer.reduce(.modifiersChanged(ShortcutModifiers(event.modifierFlags)))
        refreshDisplay()
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 {
            reducer.reduce(.cancel)
            refreshDisplay()
            window?.makeFirstResponder(nil)
            return
        }

        let effect = reducer.reduce(.keyDown(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutModifiers(event.modifierFlags),
            isRepeat: event.isARepeat
        ))
        refreshDisplay()

        switch effect {
        case .accepted(let shortcut):
            onAccepted?(shortcut)
            window?.makeFirstResponder(nil)
        case .rejected(let message):
            onError?(message)
        case .none, .ended:
            break
        }
    }

    func synchronize(keyCode: UInt32?, modifiers: ShortcutModifiers) {
        reducer.synchronize(keyCode: keyCode, modifiers: modifiers)
        refreshDisplay()
    }

    private func refreshDisplay() {
        if reducer.state.isRecording, !reducer.state.transientModifiers.isEmpty {
            stringValue = ShortcutDisplay.modifierString(reducer.state.transientModifiers)
        } else if let shortcut = reducer.state.acceptedShortcut {
            stringValue = ShortcutDisplay.string(
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers
            )
        } else {
            stringValue = reducer.state.isRecording
                ? "Type a shortcut"
                : "Click, then type a shortcut"
        }
    }
}

private extension ShortcutModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var result: ShortcutModifiers = []
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        self = result
    }
}
