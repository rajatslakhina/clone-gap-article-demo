import SwiftUI
import CloneGap

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(screen: Screen(rawValue: UserDefaults.standard.string(forKey: "screen") ?? "") ?? .gap)
        }
    }
}

enum Screen: String, CaseIterable, Identifiable {
    case gap
    case rules
    case post

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gap: return "Clone gap"
        case .rules: return "Rules"
        case .post: return "Post check"
        }
    }
}

struct RootView: View {
    @State var screen: Screen

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Screen", selection: $screen) {
                        ForEach(Screen.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                switch screen {
                case .gap: GapSections()
                case .rules: RuleSections()
                case .post: PostSections()
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("Constructed example: Tab is a fictional app. The clone is a fresh Claude agent's reply to Tab's public material, committed unchanged.")
                }
            }
            .navigationTitle("Tab vs its clone")
        }
    }
}

// MARK: - Clone gap

struct GapSections: View {
    private let report = SampleScenario.cloneReport
    private let clone = SurfaceClone()
    private let tab = TabSplitter()

    var body: some View {
        Section("Fresh agent, public material only") {
            HStack(spacing: 8) {
                Tile(value: "\(report.publishedPassed)/\(report.publishedTotal)", label: "Screenshots matched", color: .blue)
                Tile(value: "\(report.hiddenPassed)/\(report.hiddenTotal)", label: "Hidden cases matched", color: .orange)
                Tile(value: "\(report.count(.moat))", label: "Rules it missed", color: .green)
            }
            .padding(.vertical, 4)
        }
        Section("Hidden eval set") {
            ForEach(SampleScenario.hidden) { evalCase in
                let matched = evalCase.isMatched(by: clone)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: matched ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(matched ? Color.green : Color.red)
                        Text(evalCase.id).font(.caption.monospaced().weight(.bold))
                        Text(evalCase.title).font(.subheadline)
                    }
                    if !matched {
                        Text("Tab: \(Amounts.describe(tab.split(evalCase.bill), for: evalCase.bill))")
                            .font(.caption.monospaced())
                        Text("Clone: \(Amounts.describe(clone.split(evalCase.bill), for: evalCase.bill))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Rules

struct RuleSections: View {
    private let report = SampleScenario.cloneReport

    var body: some View {
        ForEach([RuleStatus.moat, .reconstructed, .leaked], id: \.self) { status in
            let findings = report.rules.filter { $0.status == status }
            Section(Self.heading(status, count: findings.count)) {
                ForEach(findings) { finding in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(finding.rule.title).font(.subheadline.weight(.semibold))
                        Text("Alternative: \(finding.rule.alternative)").font(.caption).foregroundStyle(.secondary)
                        Text(Self.evidence(finding)).font(.caption.monospaced()).foregroundStyle(Self.color(status))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    static func heading(_ status: RuleStatus, count: Int) -> String {
        switch status {
        case .moat: return "Still yours (\(count))"
        case .reconstructed: return "Worked out by the agent (\(count))"
        case .leaked: return "Leaked by screenshots (\(count))"
        case .untested: return "No case tests it (\(count))"
        }
    }

    static func evidence(_ finding: RuleFinding) -> String {
        finding.status == .leaked
            ? "Visible in " + finding.publishedCases.joined(separator: ", ")
            : "Tested by " + finding.hiddenCases.joined(separator: ", ")
    }

    static func color(_ status: RuleStatus) -> Color {
        switch status {
        case .moat: return .green
        case .reconstructed: return .orange
        case .leaked: return .red
        case .untested: return .gray
        }
    }
}

// MARK: - Post check

struct PostSections: View {
    var body: some View {
        Section("Draft Build in Public post") {
            ForEach(SampleScenario.draftPost) { part in
                let verdict = PostCheck.verdict(for: part)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(part.id).font(.subheadline)
                        Text(part.disclosure.label).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Badge(verdict: verdict)
                }
                .padding(.vertical, 2)
            }
        }
        Section("Whole post") {
            HStack {
                Text("Verdict")
                Spacer()
                Badge(verdict: PostCheck.verdict(for: SampleScenario.draftPost))
            }
        }
    }
}

// MARK: - Pieces

enum Amounts {
    static func describe(_ shares: [String: Decimal], for bill: Bill) -> String {
        bill.people.map { person in
            "\(person) \(NSDecimalNumber(decimal: shares[person] ?? 0).stringValue)"
        }
        .joined(separator: " · ")
    }
}

struct Tile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.monospacedDigit().weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Badge: View {
    let verdict: PostVerdict

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var text: String {
        switch verdict {
        case .share: return "Share"
        case .holdUntilLaunch: return "After launch"
        case .never: return "Never"
        }
    }

    private var color: Color {
        switch verdict {
        case .share: return .green
        case .holdUntilLaunch: return .orange
        case .never: return .red
        }
    }
}
