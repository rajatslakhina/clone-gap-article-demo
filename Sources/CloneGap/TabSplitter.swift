import Foundation

/// The product decisions behind Tab's split. `TabRules.tab` is what ships;
/// every other combination is a plausible alternative a competitor might pick.
public struct TabRules: Sendable, Equatable {
    public enum TipBase: Sendable, Equatable {
        /// Tip on what was ordered, before coupons and before tax.
        case itemsBeforeCoupons
        /// Tip on what was ordered after coupons, before tax.
        case itemsAfterCoupons
        /// Tip on the total including tax.
        case afterTax
    }

    public enum Leftover: Sendable, Equatable {
        /// Everyone else rounds down; the payer absorbs the leftover units.
        case payerAbsorbs
        /// Everyone else rounds down; whoever is listed first absorbs them.
        case firstPersonAbsorbs
        /// Leftover units go one at a time to the largest remainders.
        case largestRemainder
    }

    public var tipBase: TipBase = .itemsBeforeCoupons
    public var leftover: Leftover = .payerAbsorbs
    /// Round tax and tip once for the bill (true) or per person (false).
    public var roundAtBillLevel = true
    /// Use ISO 4217 digits (true) or always two decimals (false).
    public var isoCurrencyDigits = true
    /// Coupons come off in proportion to what each person ordered (true) or evenly (false).
    public var couponsProportional = true
    /// A coupon named for some people only reduces their share (true) or the whole bill (false).
    public var couponsHonourSharedBy = true
    public var serviceChargeTipped = false
    /// Service charges split evenly (true) or in proportion to what was ordered (false).
    public var serviceChargeEven = true
    public var serviceChargeTaxed = false
    /// People who ordered nothing pay no service charge (true) or an equal part of it (false).
    public var serviceChargeDinersOnly = true

    public init() {}

    /// The rules Tab ships with.
    public static let tab = TabRules()
}

/// Tab's own splitter: the reference every eval case is written against.
public struct TabSplitter: BillSplitter {
    public let rules: TabRules

    public init(rules: TabRules = .tab) {
        self.rules = rules
    }

    public func split(_ bill: Bill) -> [String: Decimal] {
        var seen = Set<String>()
        let people = bill.people.filter { seen.insert($0).inserted }
        guard let first = people.first else { return [:] }
        let scale = rules.isoCurrencyDigits ? Money.minorUnits(for: bill.currencyCode) : 2

        func owners(_ line: LineItem) -> [String] {
            line.sharedBy.isEmpty ? people : people.filter { line.sharedBy.contains($0) }
        }
        func zeros() -> [String: Decimal] {
            Dictionary(uniqueKeysWithValues: people.map { ($0, Decimal(0)) })
        }
        func sum(_ ledger: [String: Decimal], _ names: [String]) -> Decimal {
            names.reduce(Decimal(0)) { $0 + (ledger[$1] ?? 0) }
        }

        // What each person ordered, exact.
        var ordered = zeros()
        for line in bill.items where line.kind == .item && line.amount > 0 {
            let who = owners(line)
            guard !who.isEmpty else { continue }
            for p in who { ordered[p, default: 0] += line.amount / Decimal(who.count) }
        }

        // Coupons.
        var coupons = zeros()
        for line in bill.items where line.kind == .discount && line.amount > 0 {
            let who = rules.couponsHonourSharedBy ? owners(line) : people
            let base = sum(ordered, who)
            guard base > 0 else { continue }
            let amount = min(line.amount, base)
            for p in who {
                coupons[p, default: 0] += rules.couponsProportional
                    ? amount * (ordered[p] ?? 0) / base
                    : amount / Decimal(who.count)
            }
        }

        // Service charges.
        let diners = people.filter { (ordered[$0] ?? 0) > 0 }
        var service = zeros()
        for line in bill.items where line.kind == .serviceCharge && line.amount > 0 {
            var who = owners(line)
            if rules.serviceChargeDinersOnly { who = who.filter { diners.contains($0) } }
            guard !who.isEmpty else { continue }
            let base = sum(ordered, who)
            for p in who {
                service[p, default: 0] += rules.serviceChargeEven || base == 0
                    ? line.amount / Decimal(who.count)
                    : line.amount * (ordered[p] ?? 0) / base
            }
        }

        // Tax and tip bases, per person.
        let taxRate = bill.taxPercent / 100
        let tipRate = bill.tipPercent / 100
        var taxBase = zeros()
        var tipBeforeTax = zeros()
        for p in people {
            let afterCoupons = (ordered[p] ?? 0) - (coupons[p] ?? 0)
            taxBase[p] = afterCoupons + (rules.serviceChargeTaxed ? (service[p] ?? 0) : 0)
            let tipItems = rules.tipBase == .itemsBeforeCoupons ? (ordered[p] ?? 0) : afterCoupons
            tipBeforeTax[p] = tipItems + (rules.serviceChargeTipped ? (service[p] ?? 0) : 0)
        }

        // Rounded per person: what a split-each-line-then-round app shows.
        if !rules.roundAtBillLevel {
            var shares: [String: Decimal] = [:]
            for p in people {
                let tax = (taxBase[p] ?? 0) * taxRate
                let tipBase = (tipBeforeTax[p] ?? 0) + (rules.tipBase == .afterTax ? tax : 0)
                let exact = (ordered[p] ?? 0) - (coupons[p] ?? 0) + (service[p] ?? 0) + tax + tipBase * tipRate
                shares[p] = Money.round(exact, scale: scale)
            }
            return shares
        }

        // Rounded once, at bill level: the summary line on screen.
        let taxBaseTotal = sum(taxBase, people)
        let tax = Money.round(taxBaseTotal * taxRate, scale: scale)
        var tipBase = tipBeforeTax
        if rules.tipBase == .afterTax, taxBaseTotal > 0 {
            for p in people { tipBase[p, default: 0] += tax * (taxBase[p] ?? 0) / taxBaseTotal }
        }
        let tipBaseTotal = sum(tipBase, people)
        let tip = Money.round(tipBaseTotal * tipRate, scale: scale)
        let beforeExtras = sum(ordered, people) - sum(coupons, people) + sum(service, people)
        let total = Money.round(beforeExtras, scale: scale) + tax + tip

        var exact = zeros()
        for p in people {
            var value = (ordered[p] ?? 0) - (coupons[p] ?? 0) + (service[p] ?? 0)
            if taxBaseTotal > 0 { value += tax * (taxBase[p] ?? 0) / taxBaseTotal }
            if tipBaseTotal > 0 { value += tip * (tipBase[p] ?? 0) / tipBaseTotal }
            exact[p] = value
        }

        switch rules.leftover {
        case .payerAbsorbs, .firstPersonAbsorbs:
            let absorber = rules.leftover == .payerAbsorbs && people.contains(bill.payer) ? bill.payer : first
            var shares: [String: Decimal] = [:]
            var allocated = Decimal(0)
            for p in people where p != absorber {
                let share = Money.floor(exact[p] ?? 0, scale: scale)
                shares[p] = share
                allocated += share
            }
            shares[absorber] = total - allocated
            return shares

        case .largestRemainder:
            let unit = Decimal(minorUnits: 1, scale: scale)
            var shares: [String: Decimal] = [:]
            var allocated = Decimal(0)
            for p in people {
                let share = Money.floor(exact[p] ?? 0, scale: scale)
                shares[p] = share
                allocated += share
            }
            let order = people.enumerated().sorted { a, b in
                let ra = (exact[a.element] ?? 0) - (shares[a.element] ?? 0)
                let rb = (exact[b.element] ?? 0) - (shares[b.element] ?? 0)
                return ra == rb ? a.offset < b.offset : ra > rb
            }.map(\.element)
            var left = total - allocated
            var index = 0
            while left >= unit, !order.isEmpty {
                let p = order[index % order.count]
                shares[p, default: 0] += unit
                left -= unit
                index += 1
            }
            return shares
        }
    }
}
