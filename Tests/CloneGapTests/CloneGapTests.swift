import XCTest
@testable import CloneGap

private func money(_ cents: Int) -> Decimal { Decimal(minorUnits: cents, scale: 2) }

final class MoneyTests: XCTestCase {
    func testCurrencyDigits() {
        XCTAssertEqual(Money.minorUnits(for: "USD"), 2)
        XCTAssertEqual(Money.minorUnits(for: "jpy"), 0)
        XCTAssertEqual(Money.minorUnits(for: "BHD"), 3)
        XCTAssertEqual(Money.minorUnits(for: "XYZ"), 2)
    }

    func testMinorUnitsInitialiserIsExact() {
        XCTAssertEqual(Decimal(minorUnits: 3334, scale: 2), Decimal(string: "33.34"))
        XCTAssertEqual(Decimal(minorUnits: -5, scale: 2), Decimal(string: "-0.05"))
        XCTAssertEqual(Decimal(minorUnits: 7, scale: 0), Decimal(7))
    }

    func testRoundingHalfUpAndFloor() {
        XCTAssertEqual(Money.round(Decimal(string: "4.275") ?? 0, scale: 2), money(4_28))
        XCTAssertEqual(Money.floor(Decimal(string: "19.0515") ?? 0, scale: 2), money(19_05))
        XCTAssertEqual(Money.round(Decimal(1000) / 3, scale: 0), Decimal(333))
    }
}

final class TabSplitterTests: XCTestCase {
    let tab = TabSplitter()

    func testEveryCaseMatchesTabsOwnRules() {
        for c in SampleScenario.allCases {
            XCTAssertTrue(c.isMatched(by: tab), "\(c.id) \(c.title)")
        }
    }

    func testSharesAlwaysAddUpToTheBill() throws {
        // H10 by hand: 30.03 × 8.25% = 2.477475, rounded once to 2.48. Total 32.51.
        let h10 = try XCTUnwrap(SampleScenario.hidden.first { $0.id == "H10" })
        let shares = tab.split(h10.bill)
        XCTAssertEqual(shares.values.reduce(0, +), money(32_51))
        // Ben and Cy round down from 10.8366…; the payer absorbs the two cents.
        XCTAssertEqual(shares["Ana"], money(10_85))
    }

    func testTipIsOnTheOrderBeforeCoupons() throws {
        // H4 by hand: items 80, coupon 20, tax 10% of 60 = 6, tip 20% of 80 = 16. Total 82.
        let h4 = try XCTUnwrap(SampleScenario.hidden.first { $0.id == "H4" })
        XCTAssertEqual(tab.split(h4.bill).values.reduce(0, +), money(82_00))
    }

    func testEmptyTableAndUnknownPayer() {
        XCTAssertTrue(tab.split(Bill(currencyCode: "USD", people: [], payer: "Ana", items: [])).isEmpty)
        let bill = Bill(currencyCode: "USD", people: ["Ana", "Ben", "Cy"], payer: "Zed",
                        items: [LineItem("Groceries", money(100_00))])
        XCTAssertEqual(tab.split(bill)["Ana"], money(33_34), "unknown payer: first person absorbs")
    }

    func testLinesForPeopleNotAtTheTableAreIgnored() {
        let bill = Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                        items: [LineItem("Tea", money(4_00), sharedBy: ["Zed"]),
                                LineItem("Cake", money(6_00), sharedBy: ["Ben"])])
        XCTAssertEqual(tab.split(bill), ["Ana": 0, "Ben": money(6_00)])
    }

    func testCouponCannotExceedWhatItAppliesTo() {
        let bill = Bill(currencyCode: "USD", people: ["Ana", "Ben"], payer: "Ana",
                        items: [LineItem("Toast", money(5_00), sharedBy: ["Ben"]),
                                LineItem("Coupon", money(9_00), kind: .discount, sharedBy: ["Ben"])])
        XCTAssertEqual(tab.split(bill), ["Ana": 0, "Ben": 0])
    }

    func testLargestRemainderStillAddsUp() throws {
        var rules = TabRules.tab
        rules.leftover = .largestRemainder
        let s4 = try XCTUnwrap(SampleScenario.published.first { $0.id == "S4" })
        let shares = TabSplitter(rules: rules).split(s4.bill)
        XCTAssertEqual(shares.values.reduce(0, +), money(62_50))
        XCTAssertEqual(shares["Ana"], money(15_63))
        XCTAssertEqual(shares["Dee"], money(15_62))
    }

    func testPerPersonRoundingDriftsFromTheTotal() throws {
        var rules = TabRules.tab
        rules.roundAtBillLevel = false
        let s2 = try XCTUnwrap(SampleScenario.published.first { $0.id == "S2" })
        XCTAssertEqual(TabSplitter(rules: rules).split(s2.bill).values.reduce(0, +), money(99_99))
    }
}

final class CloneGapTests: XCTestCase {
    func testEveryRuleIsTestedBySomeCase() {
        let matrix = CloneGap.killMatrix(SampleScenario.allCases)
        for rule in Rule.allCases {
            XCTAssertFalse((matrix[rule] ?? []).isEmpty, "\(rule) has no case that tells it apart")
        }
        XCTAssertEqual(matrix[.tipBeforeCoupons], ["H4", "H13"])
        XCTAssertEqual(matrix[.serviceChargeEven], ["H8"])
        XCTAssertEqual(matrix[.payerAbsorbsLeftovers], ["H1"])
        XCTAssertEqual(matrix[.tipBeforeTax], ["S1", "S4", "H4", "H11", "H13"])
    }

    func testThreeRulesLeakedThroughTheScreenshots() {
        let report = SampleScenario.referenceReport
        let leaked = report.rules.filter { $0.status == .leaked }.map(\.rule)
        XCTAssertEqual(leaked, [.tipBeforeTax, .oneAbsorberForLeftovers, .billLevelRounding])
    }

    func testReferenceHasNoGap() {
        let report = SampleScenario.referenceReport
        XCTAssertEqual(report.failedCases, [])
        XCTAssertEqual(report.count(.moat), 0)
        XCTAssertEqual(report.count(.reconstructed), 9)
    }

    func testTheAgentsClone() {
        let report = SampleScenario.cloneReport
        XCTAssertEqual(report.publishedPassed, 4)
        XCTAssertEqual(report.publishedTotal, 4)
        XCTAssertEqual(report.hiddenPassed, 10)
        XCTAssertEqual(report.hiddenTotal, 13)
        XCTAssertEqual(report.failedCases, ["H4", "H8", "H13"])
        XCTAssertEqual(report.rules.filter { $0.status == .moat }.map(\.rule),
                       [.tipBeforeCoupons, .serviceChargeEven])
        XCTAssertEqual(report.count(.leaked), 3)
        XCTAssertEqual(report.count(.reconstructed), 7)
        XCTAssertEqual(report.count(.untested), 0)
    }

    func testRulesWithNoCasesAreUntestedNotMoats() {
        let report = CloneGap.measure(SurfaceClone(), named: "clone", cases: [])
        XCTAssertEqual(report.count(.untested), Rule.allCases.count)
        XCTAssertEqual(report.hiddenTotal, 0)
    }

    func testMissingPersonCountsAsZero() {
        struct DropsZeroes: BillSplitter {
            func split(_ bill: Bill) -> [String: Decimal] {
                TabSplitter().split(bill).filter { $0.value != 0 }
            }
        }
        let h12 = SampleScenario.hidden.first { $0.id == "H12" }
        XCTAssertEqual(h12?.isMatched(by: DropsZeroes()), true)
    }
}

final class PostCheckTests: XCTestCase {
    func testNumbersAreFineOnceTheFeatureShips() {
        XCTAssertEqual(PostCheck.verdict(for: PostPart(id: "a", disclosure: .realNumbers, featureShipped: true)), .share)
        XCTAssertEqual(PostCheck.verdict(for: PostPart(id: "b", disclosure: .realNumbers, featureShipped: false)), .holdUntilLaunch)
    }

    func testEvalCasesAndRuleTablesNeverShip() {
        XCTAssertEqual(PostCheck.verdict(for: PostPart(id: "c", disclosure: .evalCase, featureShipped: true)), .never)
        XCTAssertEqual(PostCheck.verdict(for: PostPart(id: "d", disclosure: .ruleTable, featureShipped: true)), .never)
    }

    func testAPostTakesItsStrictestPart() {
        XCTAssertEqual(PostCheck.verdict(for: SampleScenario.draftPost), .never)
        XCTAssertEqual(PostCheck.verdict(for: []), .share)
        let verdicts = SampleScenario.draftPost.map(PostCheck.verdict(for:))
        XCTAssertEqual(verdicts, [.share, .share, .holdUntilLaunch, .holdUntilLaunch, .never, .share])
    }
}
