import Foundation

/// Currency digits and Decimal rounding.
public enum Money {
    private static let zeroDigit: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF"
    ]
    private static let threeDigit: Set<String> = ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]

    /// ISO 4217 minor units: JPY has 0, BHD has 3, most currencies have 2.
    public static func minorUnits(for currencyCode: String) -> Int {
        let code = currencyCode.uppercased()
        if zeroDigit.contains(code) { return 0 }
        if threeDigit.contains(code) { return 3 }
        return 2
    }

    /// Rounds to `scale` decimal places. `.plain` rounds halves away from zero.
    public static func round(_ value: Decimal, scale: Int,
                             mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, mode)
        return output
    }

    /// Rounds toward zero. Shares are never negative under Tab's rules.
    public static func floor(_ value: Decimal, scale: Int) -> Decimal {
        round(value, scale: scale, mode: .down)
    }
}

extension Decimal {
    /// An exact amount from whole minor units: `Decimal(minorUnits: 3334, scale: 2)` is 33.34.
    public init(minorUnits: Int, scale: Int) {
        self.init(sign: minorUnits < 0 ? .minus : .plus,
                  exponent: -scale,
                  significand: Decimal(minorUnits.magnitude))
    }
}
