import Foundation

/// A constructed example: "Tab", a fictional bill-splitting app, with four
/// published screenshots and a hidden eval set of thirteen cases. The
/// expected amounts were worked out by hand; the tests check that Tab's own
/// rules reproduce every one of them.
public enum SampleScenario {
    /// An amount in a two-decimal currency, from minor units: 3334 is 33.34.
    private static func money(_ cents: Int) -> Decimal { Decimal(minorUnits: cents, scale: 2) }
    private static func bhd(_ fils: Int) -> Decimal { Decimal(minorUnits: fils, scale: 3) }
    private static func item(_ name: String, _ amount: Decimal, _ who: [String] = []) -> LineItem {
        LineItem(name, amount, kind: .item, sharedBy: who)
    }
    private static func coupon(_ amount: Decimal, _ who: [String] = []) -> LineItem {
        LineItem("Coupon", amount, kind: .discount, sharedBy: who)
    }
    private static func service(_ amount: Decimal) -> LineItem {
        LineItem("Service charge", amount, kind: .serviceCharge)
    }

    /// The four screenshots Tab's developer has posted.
    public static let published: [EvalCase] = [
        EvalCase(
            id: "S1", title: "Friday dinner", visibility: .published,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy"], payer: "Ana",
                       items: [item("Pizza", money(36_00)), item("Salad", money(12_00), ["Ana"]),
                               item("Beer", money(9_00), ["Ben"]), item("Soda", money(3_00), ["Cy"])],
                       taxPercent: 8, tipPercent: 20),
            expected: ["Ana": money(30_72), "Ben": money(26_88), "Cy": money(19_20)]),
        EvalCase(
            id: "S2", title: "Groceries", visibility: .published,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy"], payer: "Ana",
                       items: [item("Groceries", money(100_00))]),
            expected: ["Ana": money(33_34), "Ben": money(33_33), "Cy": money(33_33)]),
        EvalCase(
            id: "S3", title: "Coffee", visibility: .published,
            bill: Bill(currencyCode: "EUR", people: ["Dee", "Eli"], payer: "Dee",
                       items: [item("Coffee", money(4_50))], tipPercent: 10),
            expected: ["Dee": money(2_48), "Eli": money(2_47)]),
        EvalCase(
            id: "S4", title: "Team lunch", visibility: .published,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy", "Dee"], payer: "Ana",
                       items: [item("Lunch platter", money(50_00))], taxPercent: 10, tipPercent: 15),
            expected: ["Ana": money(15_64), "Ben": money(15_62), "Cy": money(15_62), "Dee": money(15_62)])
    ]

    /// The team's hidden eval set: cases Tab itself never posted. They are
    /// public here only because Tab is fictional.
    public static let hidden: [EvalCase] = [
        EvalCase(
            id: "H1", title: "The payer is listed last", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy"], payer: "Cy",
                       items: [item("Groceries", money(100_00))]),
            expected: ["Ana": money(33_33), "Ben": money(33_33), "Cy": money(33_34)]),
        EvalCase(
            id: "H2", title: "Yen has no decimals", visibility: .hidden,
            bill: Bill(currencyCode: "JPY", people: ["Ana", "Ben", "Cy"], payer: "Ana",
                       items: [item("Ramen", Decimal(1000))]),
            expected: ["Ana": Decimal(334), "Ben": Decimal(333), "Cy": Decimal(333)]),
        EvalCase(
            id: "H3", title: "Bahraini dinar has three", visibility: .hidden,
            bill: Bill(currencyCode: "BHD", people: ["Ana", "Ben", "Cy"], payer: "Ana",
                       items: [item("Mezze", bhd(10_000))]),
            expected: ["Ana": bhd(3_334), "Ben": bhd(3_333), "Cy": bhd(3_333)]),
        EvalCase(
            id: "H4", title: "Coupon, tax and tip", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                       items: [item("Steak", money(40_00), ["Ana"]), item("Pasta", money(40_00), ["Ben"]),
                               coupon(money(20_00))],
                       taxPercent: 10, tipPercent: 20),
            expected: ["Ana": money(41_00), "Ben": money(41_00)]),
        EvalCase(
            id: "H5", title: "Coupon on an uneven order", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                       items: [item("Platter", money(30_00), ["Ana"]), item("Fries", money(10_00), ["Ben"]),
                               coupon(money(8_00))]),
            expected: ["Ana": money(24_00), "Ben": money(8_00)]),
        EvalCase(
            id: "H6", title: "Coupon for one person", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                       items: [item("Burger", money(20_00), ["Ana"]), item("Burger", money(20_00), ["Ben"]),
                               coupon(money(5_00), ["Ben"])]),
            expected: ["Ana": money(20_00), "Ben": money(15_00)]),
        EvalCase(
            id: "H7", title: "Service charge and tip", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                       items: [item("Curry", money(50_00), ["Ana"]), item("Curry", money(50_00), ["Ben"]),
                               service(money(10_00))],
                       tipPercent: 20),
            expected: ["Ana": money(65_00), "Ben": money(65_00)]),
        EvalCase(
            id: "H8", title: "Service charge on an uneven order", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                       items: [item("Tasting menu", money(90_00), ["Ana"]), item("Soup", money(10_00), ["Ben"]),
                               service(money(10_00))]),
            expected: ["Ana": money(95_00), "Ben": money(15_00)]),
        EvalCase(
            id: "H9", title: "Service charge and tax", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                       items: [item("Pizza", money(50_00), ["Ana"]), item("Pizza", money(50_00), ["Ben"]),
                               service(money(10_00))],
                       taxPercent: 10),
            expected: ["Ana": money(60_00), "Ben": money(60_00)]),
        EvalCase(
            id: "H10", title: "Odd tax rate, rounded once", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy"], payer: "Ana",
                       items: [item("Bowl", money(10_01), ["Ana"]), item("Bowl", money(10_01), ["Ben"]),
                               item("Bowl", money(10_01), ["Cy"])],
                       taxPercent: Decimal(minorUnits: 825, scale: 2)),
            expected: ["Ana": money(10_85), "Ben": money(10_83), "Cy": money(10_83)]),
        EvalCase(
            id: "H11", title: "Tax and tip on uneven orders", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy"], payer: "Ana",
                       items: [item("Fish", money(25_00), ["Ana"]), item("Tacos", money(15_00), ["Ben"]),
                               item("Salad", money(7_50), ["Cy"])],
                       taxPercent: 9, tipPercent: 18),
            expected: ["Ana": money(31_76), "Ben": money(19_05), "Cy": money(9_52)]),
        EvalCase(
            id: "H12", title: "Someone who only came for the company", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben", "Dee"], payer: "Ana",
                       items: [item("Noodles", money(20_00), ["Ana"]), item("Noodles", money(20_00), ["Ben"]),
                               service(money(6_00))]),
            expected: ["Ana": money(23_00), "Ben": money(23_00), "Dee": money(0)]),
        EvalCase(
            id: "H13", title: "Shared plate, coupon and tip", visibility: .hidden,
            bill: Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ben",
                       items: [item("Sharing board", money(100_00)), coupon(money(10_00))],
                       tipPercent: 15),
            expected: ["Ana": money(52_50), "Ben": money(52_50)])
    ]

    public static var allCases: [EvalCase] { published + hidden }

    /// The red-team result: a fresh agent's clone, built from `published` only.
    public static var cloneReport: GapReport {
        CloneGap.measure(SurfaceClone(), named: "Fresh agent, public material only", cases: allCases)
    }

    /// Tab against itself: every case should pass.
    public static var referenceReport: GapReport {
        CloneGap.measure(TabSplitter(), named: "Tab", cases: allCases)
    }

    /// A draft Build in Public post, checked part by part.
    public static let draftPost: [PostPart] = [
        PostPart(id: "How we test rounding with an eval set", disclosure: .processLesson, featureShipped: true),
        PostPart(id: "Why we moved to Decimal from Double", disclosure: .architectureDecision, featureShipped: true),
        PostPart(id: "Screenshot: coupons screen (beta)", disclosure: .unreleasedScreen, featureShipped: false),
        PostPart(id: "Same screenshot shows $41.00 each", disclosure: .realNumbers, featureShipped: false),
        PostPart(id: "Table: who absorbs leftover cents", disclosure: .ruleTable, featureShipped: true),
        PostPart(id: "Crash-free sessions: 99.9%", disclosure: .aggregateMetric, featureShipped: true)
    ]
}
