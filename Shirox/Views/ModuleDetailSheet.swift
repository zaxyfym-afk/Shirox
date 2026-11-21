import SwiftUI

/// What a Test came back with, shared by the store's detail page and an installed module's.
enum ModuleDetailOutcome: Equatable {
    case running
    case passed
    case failed(step: ModuleCheckStep, reason: String)
    case needsVerification(host: String)
    case skipped(reason: String)

    init(_ result: ModuleCheckResult) {
        switch result {
        case .passed: self = .passed
        case .failed(let step, let reason): self = .failed(step: step, reason: reason)
        case .needsVerification(let host): self = .needsVerification(host: host)
        case .skipped(let reason): self = .skipped(reason: reason)
        }
    }
}

/// The check's answer, drawn once for every page that runs a Test: a quiet result box saying
/// exactly what happened — success, the step it failed on and why, or why it couldn't run.
struct ModuleTestResultView: View {
    let outcome: ModuleDetailOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch outcome {
            case .running:
                Label("modules.testing", icon: "hourglass")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            case .passed:
                Label("modules.test_passed", icon: "checkmark.seal.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            case .failed(let step, let reason):
                VStack(alignment: .leading, spacing: 3) {
                    Label("modules.test_failed \(step.label)", icon: "xmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            case .needsVerification(let host):
                VStack(alignment: .leading, spacing: 3) {
                    Label("modules.test_needs_check", icon: "shield.lefthalf.filled")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("modules.test_needs_check_note \(host)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .skipped(let reason):
                Label(reason, icon: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

/// One module in full, from wherever it was opened: who made it, where it comes from, whether
/// it works, and the things to do about it — activate, Test, Copy Link, and remove.
/// Minimal on purpose: the facts and the actions, nothing else.
struct ModuleDetailSheet: View {
    @EnvironmentObject private var moduleManager: ModuleManager
    @Environment(\.dismiss) private var dismiss
    let module: ModuleDefinition

    @State private var outcome: ModuleDetailOutcome?
    @State private var confirmingRemoval = false

    /// The install link someone else can paste into Add Module, or nil when the module came
    /// from files on the device and has nothing to copy.
    private var sourceLink: String? {
        let link = module.jsonUrl ?? ""
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    actions
                    facts
                    if let outcome {
                        ModuleTestResultView(outcome: outcome)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .softScrollEdges()
            .navigationTitle(module.sourceName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .confirmationDialog("modules.remove_module_title", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("common.remove", role: .destructive) {
                    moduleManager.removeModule(module)
                    dismiss()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("modules.remove_module_message \(module.sourceName)")
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
        .onAppear {
            // The last check's answer, shown before anything is re-run.
            if outcome == nil, let saved = moduleManager.checkResults[module.id] {
                outcome = ModuleDetailOutcome(saved)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ModuleIconView(module: module, side: 64, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(module.sourceName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                if let author = module.author, !author.name.isEmpty {
                    Text(author.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if moduleManager.activeModule?.id == module.id {
                    Label("modules.active_source", icon: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if moduleManager.activeModule?.id != module.id, !module.isManga {
                Button {
                    moduleManager.selectModule(module)
                } label: {
                    Label("modules.use_this_source", icon: "checkmark.circle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            Button {
                runTest()
            } label: {
                HStack(spacing: 8) {
                    if case .running = outcome {
                        ProgressView().controlSize(.small)
                    }
                    // The label is "Test", exactly: the button's whole job.
                    Text("modules.test")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(isTestRunning)

            if let sourceLink {
                Button {
                    Clipboard.copy(sourceLink)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    ToastManager.shared.show(message: String(localized: "modules.module_link_copied"), type: .success, duration: 1.6)
                } label: {
                    Label("modules.copy_link", icon: "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                confirmingRemoval = true
            } label: {
                Label("common.remove", icon: "trash")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
    }

    private var isTestRunning: Bool {
        if case .running = outcome { return true }
        return moduleManager.checking.contains(module.id)
    }

    /// One full check: the module's script is loaded and run the way playing something runs
    /// it — a search, a result's episodes, an episode's stream. Nothing is faked: whatever
    /// comes back is what the page says.
    private func runTest() {
        guard !isTestRunning else { return }
        outcome = .running
        Task {
            let result = await moduleManager.check(module)
            outcome = ModuleDetailOutcome(result)
        }
    }

    // MARK: - Facts

    /// Version, source and type, one quiet line each.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !module.version.isEmpty {
                fact("modules.version", "v\(module.version)")
            }
            if let author = module.author, !author.name.isEmpty {
                fact("modules.author", author.name)
            }
            if let host = sourceHost {
                fact("modules.source", host)
            }
            fact("modules.kind", kindLabel)
        }
    }

    private var kindLabel: String {
        if module.isManga { return String(localized: "store.manga") }
        if module.isLocalPlayback { return String(localized: "modules.local_files_kind") }
        if module.isJellyfin { return "Jellyfin" }
        if module.seanime != nil { return "Seanime" }
        if let badge = module.ext?.kind.badge { return badge }
        return String(localized: "store.video")
    }

    private var sourceHost: String? {
        guard let link = sourceLink, let url = URL(string: link), let host = url.host else { return nil }
        return host
    }

    private func fact(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A module's icon at any size, with the clean fallback when there is none: the first letter
/// on a soft neutral tile — never a broken-image placeholder.
struct ModuleIconView: View {
    let module: ModuleDefinition
    var side: CGFloat = 44
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let base64 = Self.base64Payload(fromDataURI: module.iconUrl) ?? module.iconData, !base64.isEmpty {
                CachedAsyncImage(urlString: "", base64String: base64, contentMode: .fit)
                    .padding(4)
            } else if let url = module.iconUrl, !url.isEmpty {
                CachedAsyncImage(urlString: url, contentMode: .fit)
                    .padding(4)
            } else {
                monogram
            }
        }
        .frame(width: side, height: side)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Modules sometimes carry the icon inline as a `data:` URI rather than a link.
    private static func base64Payload(fromDataURI uri: String?) -> String? {
        guard let uri, uri.hasPrefix("data:") else { return nil }
        guard let comma = uri.firstIndex(of: ",") else { return nil }
        return String(uri[uri.index(after: comma)...])
    }

    private var monogram: some View {
        Text(String(module.sourceName.prefix(1)).uppercased())
            .font(.system(size: side * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}
