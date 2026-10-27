/// Something a Build in Public post would reveal.
public enum Disclosure: String, CaseIterable, Sendable {
    /// How the team works, what it tried, what it learned.
    case processLesson
    /// Why the team chose an approach, without the rule tables.
    case architectureDecision
    /// A screen from a version that is already in the App Store.
    case shippedScreen
    /// A screen from a version that isn't out yet.
    case unreleasedScreen
    /// Computed amounts on screen. Each one is a worked example of a rule.
    case realNumbers
    /// The product's decision rules, written out.
    case ruleTable
    /// A case from the hidden eval set.
    case evalCase
    /// A date or scope for something not shipped yet.
    case roadmap
    /// An aggregate number: downloads, retention, crash-free rate.
    case aggregateMetric

    public var label: String {
        switch self {
        case .processLesson: return "Process lesson"
        case .architectureDecision: return "Architecture decision"
        case .shippedScreen: return "Shipped screen"
        case .unreleasedScreen: return "Unreleased screen"
        case .realNumbers: return "Real computed numbers"
        case .ruleTable: return "Rule table"
        case .evalCase: return "Eval case"
        case .roadmap: return "Roadmap date"
        case .aggregateMetric: return "Aggregate metric"
        }
    }
}

public enum PostVerdict: String, Sendable, Comparable {
    case share
    /// Fine once the feature has launched. Launch, then reveal.
    case holdUntilLaunch
    /// Never: this is the part a competitor can't get by using the app.
    case never

    private var rank: Int {
        switch self {
        case .share: return 0
        case .holdUntilLaunch: return 1
        case .never: return 2
        }
    }

    public static func < (lhs: PostVerdict, rhs: PostVerdict) -> Bool { lhs.rank < rhs.rank }
}

/// One part of a draft post.
public struct PostPart: Sendable, Equatable, Identifiable {
    public let id: String
    public let disclosure: Disclosure
    /// Whether the feature it shows is already in the App Store.
    public let featureShipped: Bool

    public init(id: String, disclosure: Disclosure, featureShipped: Bool) {
        self.id = id
        self.disclosure = disclosure
        self.featureShipped = featureShipped
    }
}

/// A Build in Public policy for an era when an agent can rebuild what it sees.
///
/// The idea behind it: once a feature ships, the app answers any question a
/// competitor thinks to ask, so showing it costs little. Before launch, a
/// screenshot with real numbers is a spec. The eval set is different in kind:
/// it is the list of questions worth asking, and nothing in the app reveals
/// it. A rule table hands over the same list, so it never ships either.
public enum PostCheck {
    public static func verdict(for part: PostPart) -> PostVerdict {
        switch part.disclosure {
        case .processLesson, .architectureDecision, .aggregateMetric, .shippedScreen:
            return .share
        case .unreleasedScreen, .roadmap:
            return .holdUntilLaunch
        case .realNumbers:
            return part.featureShipped ? .share : .holdUntilLaunch
        case .ruleTable, .evalCase:
            return .never
        }
    }

    /// The strictest verdict across the parts of a post.
    public static func verdict(for post: [PostPart]) -> PostVerdict {
        post.map(verdict(for:)).max() ?? .share
    }
}
