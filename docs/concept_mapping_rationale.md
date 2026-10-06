# Concept mapping: why each tag maps to each concept

Ten restaurant companies report the same economics under different US-GAAP
elements. This file records which elements this project accepts for each
business concept, in what order, and the measurement behind every choice.
The machine-readable form is [`../data/concept_mapping.csv`](../data/concept_mapping.csv),
registered by the query runner as the view `concept_mapping`; no query in this
repository hardcodes a tag list.

**Documenting the criterion matters more than getting it right.** A reader who
disagrees with a choice below can see exactly what it was and recompute.

## How a concept resolves

For one company and one period, the candidate facts are ordered by
`tag_preference` and the first is taken. Two rules make that deterministic:

1. **Preference, not `coalesce`.** A blind `coalesce` over several elements
   hides which one answered. Every query returns the tag it used.
2. **A tie-break on `tag_version`, descending.** `dim_account` is grained on
   `(tag_name, tag_version)`, so one concept filed under two taxonomy years is
   two rows that both survive every hazard flag. Without the tie-break the join
   duplicates. See [`engineering-notes.md`](engineering-notes.md).

Cheesecake Factory's net income for the first quarter of 2025 has seven facts,
all 32.9 m. Three are a column of the equity statement and one was superseded,
so the flags leave three, and both rules act on them:

| Element | Taxonomy | Taken for |
|---|---|---|
| `NetIncomeLoss` | 2024 | `net_income`, first by preference |
| `ProfitLoss` | 2025 | `net_income_consolidated`, first by preference, then the newer version |
| `ProfitLoss` | 2024 | Neither |

CHECK 3 in [`../sql/01_concept_resolution.sql`](../sql/01_concept_resolution.sql)
prints all seven.

## Coverage is measured with the flags applied

The count of companies per element changes once the aggregation rules are
applied, because most of the raw facts are segment breakdowns. **The flagged
figure is the one that governs the metric catalogue.**

| Element | Companies, raw | Companies, flags applied |
|---|---|---|
| `RevenueFromContractWithCustomerExcludingAssessedTax` | 7 | **4** |
| `CostOfGoodsAndServicesSold` | 6 | **4** |
| `Revenues` | 6 | 6 |
| `NetIncomeLoss` | 8 | 8 |
| `Liabilities` | 9 | 9 |
| `OperatingIncomeLoss`, `Assets`, `AssetsCurrent`, `LiabilitiesCurrent`, `StockholdersEquity`, `NetCashProvidedByUsedInOperatingActivities` | 10 | 10 |

The 2,527 raw facts behind the first row are almost all segment detail. Reading
that 7 as coverage would have put a revenue metric on four companies while
claiming seven.

## Revenue: no single element carries it

`RevenueFromContractWithCustomerExcludingAssessedTax` reaches 4 companies and
`Revenues` 6. Neither covers the scope; **the union of the three accepted
elements reaches all ten**, quarterly and annual.

Order: the ASC 606 element first as the most specific, its tax-inclusive twin
second, the pre-606 total last. `RevenuesNetOfInterestExpense` appears in the
upstream analysis queries but **has zero facts in this scope**, so it is not in
the mapping.

## The bottom line: 8 companies become 10

`NetIncomeLoss` is the result attributable to the parent and reaches 8.
`ProfitLoss` includes noncontrolling interests and reaches 6. `NetIncomeLoss`
is preferred because it is the figure per-share calculations use; with
`ProfitLoss` as the fallback, **the concept reaches all ten**.

Restaurant Brands International and Texas Roadhouse are the two that resolve
through the fallback, and both reproduce the upstream published margins, so the
fallback is exercised by the reconciliation gate rather than assumed.

### The same two elements in the opposite order: `net_income_consolidated`

Operating cash flow is reported for the consolidated group, minority
shareholders included. Comparing it with the parent's share of profit mixes
two scopes, so the earnings-quality metrics use a second concept that resolves
the same two elements the other way round: **`ProfitLoss` first,
`NetIncomeLoss` second.**

The fallback is safe because the four companies that file no `ProfitLoss`
(Chipotle, McDonald's, Wendy's, Yum Brands) carry no noncontrolling interest:
none reports a minority share of income, and Yum Brands' NCI-inclusive equity
equals its parent equity at every instant it files it. For them the parent
result *is* the consolidated one.

The difference matters for one company. At 2025-09-30 Yum China's trailing
profit is **977 m consolidated against 904 m for the parent**. Dividing its
cash flow by the parent figure would overstate how much of its profit arrived
as cash by 8.1%. Bloomin' (-52.5 m against -57.7 m) and Papa John's (38.4 m against
38.3 m) move less. `net_income` stays the concept for margins and ROE, where
the parent's share is the figure the upstream project publishes.

## Equity: one definition, chosen on coverage

`StockholdersEquity` excludes noncontrolling interests and reaches **10**.
`StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest`
includes them and reaches **7** (Chipotle, McDonald's and Wendy's do not file
it). `StockholdersEquity` is the definition for this project.

**The NCI-inclusive element is not a fallback for it.** Mixing the two across
companies would make two equity figures incomparable. It has exactly two uses,
both below.

### Use one: the ROE pairing rule

The numerator drags the decision the other way. `ProfitLoss` **includes**
noncontrolling interests while `StockholdersEquity` **excludes** them, so a
return on equity built from that pair divides a wider profit by a narrower
capital base and overstates the result. The gap is not cosmetic: at
2024-12-31 Restaurant Brands reports 3,110 m without the minority against
4,843 m with it, **56% more**.

**The rule: the denominator follows whichever element the numerator resolved
to.** `NetIncomeLoss` pairs with `StockholdersEquity`; `ProfitLoss` pairs with
the NCI-inclusive element. Both companies that use the fallback file both
equity elements, so ROE covers all ten and no row mixes definitions. GATE 6
checks this.

Three companies carry negative book equity from buybacks, so their ROE is null
rather than a small number, and `liabilities_to_assets` is reported beside it.

### Use two: closing the balance sheet

One company, McDonald's, never files `Liabilities`, so it is derived. The naive
identity is wrong:

```
liabilities = assets - equity_incl_nci - redeemable_nci
```

**Redeemable noncontrolling interest is mezzanine**: carried outside permanent
equity and outside liabilities both. Omitting the term left Yum China short by
13 m and Papa John's by 0.9 m on every instant where they carry it, which is
how the term was found. With it, the identity closes to the cent on all nine
companies that report `Liabilities` directly (GATE 5), which is what licenses
the derivation for the tenth. McDonald's carries no minority interest of either
kind, so for it the identity reduces to assets less equity.

## Metrics not computed, each with the measurement that rules it out

| Metric | Why it is not here |
|---|---|
| `interest_coverage` | `InterestExpense` reaches **1 of 10** companies. No alternative element passes 6, and the best of those, `InterestPaidNet`, is a cash-flow item rather than an income-statement expense |
| `gross_margin_pct` | `CostOfGoodsAndServicesSold` reaches **4 of 10** with the flags applied, and 3 at the annual grain. A gross margin for four companies is not a peer comparison |
| `cost_growth_yoy_pct` | The same cost-of-revenue ceiling |

**A metric dropped with its measurement beside it is worth more than one
computed over a denominator that exists for one company.** These are recorded
so that nobody adds them later believing they were an oversight.

## What the grain allows

- **Income-statement concepts** have three complete fiscal years, 2022 to 2024,
  all ten companies. Any year-over-year series runs on three points.
- **Balance-sheet concepts are complete only from 2023-12-31.** At 2022-12-31
  `Assets` reaches 2 companies and `StockholdersEquity` 3; the current asset and
  liability elements reach none. So the annual balance sheet has two closes, not
  three, and the ratios that use it are carried on the quarterly grain instead,
  where 2024-12-31 through 2025-09-30 gives four points across all ten.
- **The fourth quarter is never filed on its own.** Where a discrete Q4 is
  needed it is the full year less the nine-month year to date, and marked as
  derived. See [`engineering-notes.md`](engineering-notes.md) for why not the
  full year less three quarters.
