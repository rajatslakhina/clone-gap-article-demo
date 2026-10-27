/// One product decision in Tab's split, paired with the most plausible
/// alternative a competitor might choose instead.
///
/// The alternative (the "mutant") is how the gap is measured: if a public
/// screenshot already tells Tab apart from its mutant, the rule has leaked.
/// If only the hidden eval set can tell them apart, it is still private.
public enum Rule: String, CaseIterable, Sendable, Hashable {
    case tipBeforeTax
    case tipBeforeCoupons
    case oneAbsorberForLeftovers
    case payerAbsorbsLeftovers
    case billLevelRounding
    case currencyDigits
    case couponsProportional
    case couponsTargeted
    case serviceChargeNotTipped
    case serviceChargeEven
    case serviceChargeNotTaxed
    case serviceChargeDinersOnly

    /// What Tab does.
    public var title: String {
        switch self {
        case .tipBeforeTax: return "Tip is calculated before tax"
        case .tipBeforeCoupons: return "Tip is calculated before coupons"
        case .oneAbsorberForLeftovers: return "One person absorbs every leftover cent"
        case .payerAbsorbsLeftovers: return "That person is the payer"
        case .billLevelRounding: return "Tax and tip are rounded once, for the bill"
        case .currencyDigits: return "Decimal places follow the currency (¥0, BD 0.000)"
        case .couponsProportional: return "Coupons come off in proportion to what was ordered"
        case .couponsTargeted: return "A coupon named for someone only reduces their share"
        case .serviceChargeNotTipped: return "No tip on the service charge"
        case .serviceChargeEven: return "Service charge is split evenly"
        case .serviceChargeNotTaxed: return "No tax on the service charge"
        case .serviceChargeDinersOnly: return "People who ordered nothing pay no service charge"
        }
    }

    /// The alternative a reasonable competitor might ship.
    public var alternative: String {
        switch self {
        case .tipBeforeTax: return "tip on the total including tax"
        case .tipBeforeCoupons: return "tip on the amount after coupons"
        case .oneAbsorberForLeftovers: return "spread leftover cents by largest remainder"
        case .payerAbsorbsLeftovers: return "whoever is listed first absorbs them"
        case .billLevelRounding: return "round each person's share separately"
        case .currencyDigits: return "always two decimal places"
        case .couponsProportional: return "split coupons evenly"
        case .couponsTargeted: return "every coupon reduces the whole bill"
        case .serviceChargeNotTipped: return "tip on the service charge too"
        case .serviceChargeEven: return "split it in proportion to what was ordered"
        case .serviceChargeNotTaxed: return "tax the service charge"
        case .serviceChargeDinersOnly: return "everyone at the table pays an equal part"
        }
    }

    /// Tab's rules with only this one decision flipped.
    public var mutant: TabRules {
        var r = TabRules.tab
        switch self {
        case .tipBeforeTax: r.tipBase = .afterTax
        case .tipBeforeCoupons: r.tipBase = .itemsAfterCoupons
        case .oneAbsorberForLeftovers: r.leftover = .largestRemainder
        case .payerAbsorbsLeftovers: r.leftover = .firstPersonAbsorbs
        case .billLevelRounding: r.roundAtBillLevel = false
        case .currencyDigits: r.isoCurrencyDigits = false
        case .couponsProportional: r.couponsProportional = false
        case .couponsTargeted: r.couponsHonourSharedBy = false
        case .serviceChargeNotTipped: r.serviceChargeTipped = true
        case .serviceChargeEven: r.serviceChargeEven = false
        case .serviceChargeNotTaxed: r.serviceChargeTaxed = true
        case .serviceChargeDinersOnly: r.serviceChargeDinersOnly = false
        }
        return r
    }
}
