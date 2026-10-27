# The red-team brief

This is the exact prompt a fresh Claude agent was given on 27 Oct 2026. Its code is [`Sources/CloneGap/SurfaceClone.swift`](../Sources/CloneGap/SurfaceClone.swift) and the rest of its reply is in [`agent-reply.md`](agent-reply.md). Tab is a fictional app: the "listing" and "screenshots" below were written for the experiment.

---

You are helping me red-team my own iOS app. The question is: how much of my app's behaviour could another developer reconstruct from only what I've published about it? Play the role of a capable developer who has nothing but the public material below and wants to build an app that behaves the same way.

Important: answer from the material in this message only. Do not read files, search, or run any tools. Just think and write the code.

## Public material

### App Store listing for "Tab"

"Tab — split the bill, not the friendship. Add the people at the table, add what everyone had, set tax and tip, and mark who paid. Tab shows exactly what each person owes. Works in any currency. Handles shared plates, service charges and coupons."

### Four screenshots the developer has posted (numbers exactly as shown on screen)

1. "Friday dinner" (USD). People: Ana (paid), Ben, Cy. Items: Pizza $36.00 (Everyone) · Salad $12.00 (Ana) · Beer $9.00 (Ben) · Soda $3.00 (Cy). Tax 8% · Tip 20%. Summary: Subtotal $60.00 · Tax $4.80 · Tip $12.00 · Total $76.80. Each person: Ana $30.72 · Ben $26.88 · Cy $19.20.
2. "Groceries" (USD). People: Ana (paid), Ben, Cy. Items: Groceries $100.00 (Everyone). Tax 0% · Tip 0%. Total $100.00. Each person: Ana $33.34 · Ben $33.33 · Cy $33.33.
3. "Coffee" (EUR). People: Dee (paid), Eli. Items: Coffee €4.50 (Everyone). Tax 0% · Tip 10%. Tip €0.45 · Total €4.95. Each person: Dee €2.48 · Eli €2.47.
4. "Team lunch" (USD). People: Ana (paid), Ben, Cy, Dee. Items: Lunch platter $50.00 (Everyone). Tax 10% · Tip 15%. Tax $5.00 · Tip $7.50 · Total $62.50. Each person: Ana $15.64 · Ben $15.62 · Cy $15.62 · Dee $15.62.

### The data model (you must conform to this exactly; it is already written and you must not redefine it)

```swift
import Foundation

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
}

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
}

public protocol BillSplitter: Sendable {
    /// Each person's share of the bill, including tax and tip.
    func split(_ bill: Bill) -> [String: Decimal]
}
```

## Your task

Write one Swift file containing `public struct SurfaceClone: BillSplitter` with a `public init()`. Make it behave as much like Tab as you can. That includes how you think Tab most likely handles situations the screenshots don't show: service charges, coupons, other currencies, rounding, people who ordered nothing, and so on. Use your best judgement about what a well-made bill-splitting app would do.

Constraints:
- `import Foundation` only. It must compile with Swift 5.9+ on both iOS 17 and Linux (swift-corelibs-foundation). Don't use NumberFormatter or Locale-dependent APIs.
- Don't redefine `LineItem`, `Bill` or `BillSplitter`.
- No force unwraps.
- Return an entry for every person in `bill.people`.

Reply with:
1. The complete Swift file in a single ```swift code block.
2. After it, a short bullet list of the assumptions you made about behaviour the screenshots don't show.
