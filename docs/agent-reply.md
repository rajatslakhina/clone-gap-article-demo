# The agent's reply

A fresh Claude agent answered [the brief](red-team-brief.md) on 27 Oct 2026. Its reply had two parts. The Swift code block is committed unchanged as [`Sources/CloneGap/SurfaceClone.swift`](../Sources/CloneGap/SurfaceClone.swift), below the provenance header. The rest of the reply follows here, word for word.

---

All four screenshots work out exactly with this code (checked by hand). As you asked, I didn't compile or run it.

**Assumptions about what the screenshots don't show**
- **Leftover pennies:** each share is rounded down to the currency's minor unit and all the leftover cents go to the payer, so nobody who owes money pays more than their exact share. Screenshots 2–4 fit this, but the payer is always listed first there, so "first person listed" fits just as well; I chose the payer. If the payer isn't in `people`, the first person gets the leftover.
- **When rounding happens:** shares stay exact through every step and are rounded once at the end, not item by item. Tax and tip are each rounded half-up at bill level, so Subtotal + Tax + Tip = Total and the shares add up to that total.
- **Tax and tip base:** both apply to the item subtotal after coupons. The tip is taken before tax, which screenshot 1 confirms.
- **Coupons:** they come off before tax and tip. Each one is spread over its people in proportion to what they ordered, or split equally if none of them ordered anything. Nobody's amount before tax goes below zero, so a coupon bigger than the food is capped, not paid out.
- **Service charges:** they're spread over their people in proportion to what each pays after coupons, or split equally if that's zero for all of them (e.g. a cover charge with no food). They carry no tax and no tip. These were my least confident guesses: whether service charges are taxed, and whether an "Everyone" coupon or service charge is split in proportion or equally.
- **People who ordered nothing:** they owe 0 and take no share of tax, tip, coupons or service charges unless they're named on a line. If one of them is the payer, they may still absorb the leftover pennies.
- **Currencies:** decimal places come from a built-in ISO 4217 table:
  - 0 for JPY, KRW, VND, CLP, ISK and the rest of that group
  - 3 for BHD, KWD, OMR, JOD, TND, LYD and IQD
  - 4 for CLF and UYW
  - 2 for everything else, including codes it doesn't recognise

  The currency code is trimmed and uppercased first.
- **Messy input:**
  - Names in `sharedBy` that aren't at the table are ignored, and a line with no valid names belongs to everyone.
  - Duplicate names count once.
  - Amounts are taken as positive, so `kind` alone decides whether a line adds or subtracts.
  - NaN is treated as 0.
  - An empty `people` list returns `[:]`.
