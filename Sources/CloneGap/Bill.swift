import Foundation

/// One line on a bill, as the user enters it.
public struct LineItem: Sendable, Equatable {
    public enum Kind: String, Sendable {
        /// Something someone ordered.
        case item
        /// A service charge added by the venue.
        case serviceCharge
        /// A coupon or discount, entered as a positive amount.
        case discount
    }

    public let name: String
    /// Always entered as a positive amount; `kind` decides what it does.
    public let amount: Decimal
    public let kind: Kind
    /// Who this line belongs to. Empty means everyone at the table.
    public let sharedBy: [String]

    public init(_ name: String, _ amount: Decimal, kind: Kind = .item, sharedBy: [String] = []) {
        self.name = name
        self.amount = amount
        self.kind = kind
        self.sharedBy = sharedBy
    }
}

/// A bill as the app sees it.
public struct Bill: Sendable, Equatable {
    /// ISO 4217 code, e.g. "USD", "EUR", "JPY".
    public let currencyCode: String
    /// Everyone at the table, in the order the app lists them.
    public let people: [String]
    /// The person who paid the venue. Everyone else owes them.
    public let payer: String
    public let items: [LineItem]
    /// Percent, e.g. 8 for 8%.
    public let taxPercent: Decimal
    /// Percent, e.g. 20 for 20%.
    public let tipPercent: Decimal

    public init(currencyCode: String, people: [String], payer: String, items: [LineItem],
                taxPercent: Decimal = 0, tipPercent: Decimal = 0) {
        self.currencyCode = currencyCode
        self.people = people
        self.payer = payer
        self.items = items
        self.taxPercent = taxPercent
        self.tipPercent = tipPercent
    }
}

/// Anything that can turn a bill into what each person owes.
public protocol BillSplitter: Sendable {
    /// Each person's share of the bill, including tax and tip.
    func split(_ bill: Bill) -> [String: Decimal]
}
