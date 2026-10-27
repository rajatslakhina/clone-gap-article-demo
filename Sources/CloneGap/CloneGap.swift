import Foundation

/// One eval case: a bill and what Tab shows for it.
public struct EvalCase: Sendable, Identifiable {
    public enum Visibility: String, Sendable {
        /// Its numbers have been posted publicly (a screenshot, a demo video).
        case published
        /// It only lives in the team's eval set.
        case hidden
    }

    public let id: String
    public let title: String
    public let visibility: Visibility
    public let bill: Bill
    /// What each person owes, as Tab shows it.
    public let expected: [String: Decimal]

    public init(id: String, title: String, visibility: Visibility, bill: Bill, expected: [String: Decimal]) {
        self.id = id
        self.title = title
        self.visibility = visibility
        self.bill = bill
        self.expected = expected
    }

    /// Whether `splitter` shows the same amounts. Each share is rounded to the
    /// currency's digits first, because that is what would be on screen; a
    /// missing person counts as owing zero.
    public func isMatched(by splitter: BillSplitter) -> Bool {
        let actual = splitter.split(bill)
        let scale = Money.minorUnits(for: bill.currencyCode)
        return bill.people.allSatisfy { person in
            Money.round(actual[person] ?? 0, scale: scale) == (expected[person] ?? 0)
        }
    }
}

/// Where a rule stands against a given competitor.
public enum RuleStatus: String, Sendable {
    /// A published case already tells Tab apart from the alternative.
    case leaked
    /// Only hidden cases tell them apart, and the competitor matched all of them.
    case reconstructed
    /// The competitor got at least one of the hidden cases for this rule wrong.
    case moat
    /// No case tells Tab apart from the alternative: an eval gap, not a moat.
    case untested
}

public struct RuleFinding: Sendable, Identifiable {
    public var id: Rule { rule }
    public let rule: Rule
    public let status: RuleStatus
    /// Cases the rule's alternative gets wrong.
    public let publishedCases: [String]
    public let hiddenCases: [String]
}

public struct GapReport: Sendable {
    public let competitor: String
    public let publishedPassed: Int
    public let publishedTotal: Int
    public let hiddenPassed: Int
    public let hiddenTotal: Int
    public let failedCases: [String]
    public let rules: [RuleFinding]

    public func count(_ status: RuleStatus) -> Int {
        rules.filter { $0.status == status }.count
    }
}

/// Measures how much of Tab a competitor reproduces, and why.
public enum CloneGap {
    /// For each rule, which cases its alternative gets wrong. A case that
    /// catches the alternative is a case that depends on the rule.
    public static func killMatrix(_ cases: [EvalCase]) -> [Rule: [String]] {
        var matrix: [Rule: [String]] = [:]
        for rule in Rule.allCases {
            let mutant = TabSplitter(rules: rule.mutant)
            matrix[rule] = cases.filter { !$0.isMatched(by: mutant) }.map(\.id)
        }
        return matrix
    }

    public static func measure(_ competitor: BillSplitter, named name: String,
                               cases: [EvalCase]) -> GapReport {
        let published = cases.filter { $0.visibility == .published }
        let hidden = cases.filter { $0.visibility == .hidden }
        let failed = Set(cases.filter { !$0.isMatched(by: competitor) }.map(\.id))
        let publishedIDs = Set(published.map(\.id))
        let matrix = killMatrix(cases)

        let findings: [RuleFinding] = Rule.allCases.map { rule in
            let killers = matrix[rule] ?? []
            let pub = killers.filter { publishedIDs.contains($0) }
            let hid = killers.filter { !publishedIDs.contains($0) }
            let status: RuleStatus
            if !pub.isEmpty {
                status = .leaked          // a screenshot already shows it
            } else if hid.isEmpty {
                status = .untested        // an eval gap, not a moat
            } else if hid.contains(where: { failed.contains($0) }) {
                status = .moat            // the clone got one wrong
            } else {
                status = .reconstructed
            }
            return RuleFinding(rule: rule, status: status, publishedCases: pub, hiddenCases: hid)
        }

        return GapReport(
            competitor: name,
            publishedPassed: published.count - published.filter { failed.contains($0.id) }.count,
            publishedTotal: published.count,
            hiddenPassed: hidden.count - hidden.filter { failed.contains($0.id) }.count,
            hiddenTotal: hidden.count,
            failedCases: cases.map(\.id).filter { failed.contains($0) },
            rules: findings
        )
    }
}
