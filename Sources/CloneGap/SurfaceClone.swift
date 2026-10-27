// SurfaceClone.swift
//
// Written by a fresh Claude agent on 27 Oct 2026, as a red-team exercise.
// It was given only Tab's public material: the App Store text, the numbers
// from the four screenshots in SampleScenario.published and the types in
// Bill.swift.
// It was told not to read files or run tools. Everything below this header
// is the code from its reply, unchanged. The brief it was given is in
// docs/red-team-brief.md and the rest of its reply, including the
// assumptions it listed, is in docs/agent-reply.md.

import Foundation

/// Tab's split, reconstructed only from its public material: the App Store
/// listing, the four screenshots and the data model.
///
/// 1. Items are split equally between the people sharing them. An empty
///    `sharedBy` means everyone at the table (Pizza $36 → $12 each).
/// 2. Coupons come off before tax and tip. Each one is spread over the people
///    it belongs to in proportion to what they ordered. Nobody's pre-tax
///    amount can drop below zero.
/// 3. Service charges are spread over the people they belong to in proportion
///    to what each person pays for after coupons. They carry no tax or tip.
/// 4. Tax and tip are percentages of the item subtotal after coupons, so the
///    tip is pre-tax (20% of $60 = $12.00). Each is rounded half-up to the
///    currency's minor unit, as on the summary, and shared in proportion to
///    that subtotal.
/// 5. Every share is rounded down to the minor unit and the payer absorbs the
///    leftover units ($33.34/$33.33/$33.33, $15.64/$15.62×3). The shares
///    therefore always add up to the bill's total.
public struct SurfaceClone: BillSplitter {
    public init() {}

    public func split(_ bill: Bill) -> [String: Decimal] {
        let people = Self.uniqued(bill.people)
        guard let firstPerson = people.first else { return [:] }
        let known = Set(people)
        let payer = known.contains(bill.payer) ? bill.payer : firstPerson
        let scale = Self.minorUnits(for: bill.currencyCode)

        // 1. What everyone had, kept exact.
        var ordered = Self.zeroLedger(for: people)
        for line in bill.items where line.kind == .item {
            let sharers = Self.sharers(of: line, people: people, known: known)
            let portion = Self.magnitude(of: line.amount) / Decimal(sharers.count)
            for person in sharers {
                ordered[person, default: 0] += portion
            }
        }
        ordered = ordered.mapValues { Self.fine($0) }

        // 2. Coupons, before tax and tip.
        var couponed = Self.zeroLedger(for: people)
        for line in bill.items where line.kind == .discount {
            let sharers = Self.sharers(of: line, people: people, known: known)
            Self.spread(Self.magnitude(of: line.amount), over: sharers,
                        weightedBy: ordered, into: &couponed)
        }
        var base = Self.zeroLedger(for: people)
        var baseSum: Decimal = 0
        for person in people {
            let net = Self.fine((ordered[person] ?? 0) - (couponed[person] ?? 0))
            let kept: Decimal = net > Self.noise ? net : 0
            base[person] = kept
            baseSum += kept
        }

        // 3. Service charges: proportional, untaxed, untipped.
        var service = Self.zeroLedger(for: people)
        var serviceSum: Decimal = 0
        for line in bill.items where line.kind == .serviceCharge {
            let amount = Self.magnitude(of: line.amount)
            let sharers = Self.sharers(of: line, people: people, known: known)
            serviceSum += amount
            Self.spread(amount, over: sharers, weightedBy: base, into: &service)
        }

        // 4. Bill-level tax and tip, rounded as shown on the summary.
        let subtotal = Self.settle(baseSum)
        let tax = Self.rounded(subtotal * Self.finite(bill.taxPercent) / 100,
                               scale: scale, mode: .plain)
        let tip = Self.rounded(subtotal * Self.finite(bill.tipPercent) / 100,
                               scale: scale, mode: .plain)
        let extras = tax + tip
        let total = Self.rounded(Self.settle(baseSum + serviceSum),
                                 scale: scale, mode: .plain) + extras

        // 5. Round every share down; the payer absorbs what's left over.
        var shares: [String: Decimal] = [:]
        var allocated: Decimal = 0
        for person in people {
            let personBase = base[person] ?? 0
            var exact = personBase + (service[person] ?? 0)
            if baseSum > 0 {
                exact += extras * personBase / baseSum
            }
            let share = Self.floored(Self.settle(exact), scale: scale)
            shares[person] = share
            allocated += share
        }
        shares[payer, default: 0] += total - allocated
        return shares
    }
}

// MARK: - Helpers

extension SurfaceClone {
    /// Decimal division noise below this is treated as zero.
    private static var noise: Decimal {
        Decimal(sign: .plus, exponent: -18, significand: 1)
    }

    /// ISO 4217 minor units that differ from the usual two.
    private static let zeroDecimalCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF",
    ]
    private static let threeDecimalCurrencies: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND",
    ]
    private static let fourDecimalCurrencies: Set<String> = ["CLF", "UYW"]

    private static func minorUnits(for currencyCode: String) -> Int {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if zeroDecimalCurrencies.contains(code) { return 0 }
        if threeDecimalCurrencies.contains(code) { return 3 }
        if fourDecimalCurrencies.contains(code) { return 4 }
        return 2
    }

    private static func uniqued(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    private static func zeroLedger(for people: [String]) -> [String: Decimal] {
        var ledger: [String: Decimal] = [:]
        for person in people {
            ledger[person] = 0
        }
        return ledger
    }

    /// The people a line belongs to: the named people who are at the table,
    /// each counted once. If nobody valid is named, it is everyone.
    private static func sharers(of line: LineItem, people: [String], known: Set<String>) -> [String] {
        var seen = Set<String>()
        var named: [String] = []
        for name in line.sharedBy where known.contains(name) {
            if seen.insert(name).inserted {
                named.append(name)
            }
        }
        return named.isEmpty ? people : named
    }

    /// Spreads `amount` over `sharers` in proportion to `weights`. If none of
    /// them has any weight, it is split equally.
    private static func spread(
        _ amount: Decimal,
        over sharers: [String],
        weightedBy weights: [String: Decimal],
        into ledger: inout [String: Decimal]
    ) {
        guard !sharers.isEmpty else { return }
        var totalWeight: Decimal = 0
        for person in sharers {
            let weight = weights[person] ?? 0
            if weight > noise {
                totalWeight += weight
            }
        }
        if totalWeight > noise {
            for person in sharers {
                let weight = weights[person] ?? 0
                guard weight > noise else { continue }
                ledger[person, default: 0] += fine(amount * weight / totalWeight)
            }
        } else {
            let portion = fine(amount / Decimal(sharers.count))
            for person in sharers {
                ledger[person, default: 0] += portion
            }
        }
    }

    /// Amounts are always entered as positive; `kind` decides the sign.
    private static func magnitude(of value: Decimal) -> Decimal {
        if value.isNaN { return 0 }
        return value < 0 ? -value : value
    }

    private static func finite(_ value: Decimal) -> Decimal {
        value.isNaN ? 0 : value
    }

    private static func rounded(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, mode)
        return output
    }

    /// Rounds toward negative infinity, the same way on Darwin and Linux.
    private static func floored(_ value: Decimal, scale: Int) -> Decimal {
        if value < 0 {
            return -rounded(-value, scale: scale, mode: .up)
        }
        return rounded(value, scale: scale, mode: .down)
    }

    /// Removes Decimal division noise and keeps far more precision than any
    /// currency needs.
    private static func fine(_ value: Decimal) -> Decimal {
        rounded(value, scale: 24, mode: .plain)
    }

    /// Settles a value before rounding it to a minor unit, so 9.999…9 from
    /// adding thirds counts as 10.
    private static func settle(_ value: Decimal) -> Decimal {
        rounded(value, scale: 12, mode: .plain)
    }
}
