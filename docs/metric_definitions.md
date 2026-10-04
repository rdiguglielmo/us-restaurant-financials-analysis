# Metric Definitions

The eight metrics this repository computes: the formula, the view and column
that carry each one, the rule for nulls and flags, and the coverage measured
with the aggregation flags applied. Why each rule is the way it is lives in
[`engineering-notes.md`](engineering-notes.md) and
[`concept_mapping_rationale.md`](concept_mapping_rationale.md); this file does
not repeat it.

Every coverage figure below is printed by a section of the query chain. A
bracketed label names it: [GATE 6] is in `sql/00_reconciliation_gate.sql`,
[E6] in `sql/02_financial_statements.sql`, [R6] in `sql/03_ratios.sql`, [Q4] in
`sql/04_earnings_quality.sql` and [K4] in `sql/05_peer_ranking.sql`.

## Grains

| Grain | Views | Periods | Rows |
|---|---|---|---|
| Annual | `ratios_annual`, `earnings_quality_annual` | FY2022 to FY2024 | 30 |
| Quarterly | `ratios_quarterly` | 2024 Q1 to 2025 Q3, discrete, Q4 2024 derived | 70 |
| Trailing twelve months | `ratios_ttm`, `earnings_quality_ttm` | The four quarter ends from 2024-12-31 to 2025-09-30 | 40 |

A balance-sheet figure is taken at the period end of the row. Wherever a flow
is divided by a balance, the flow covers twelve months, a fiscal year or a
trailing twelve months, so that no single quarter of a seasonal business is
annualised.

The concepts in the formulas are the business concepts of
[`../data/concept_mapping.csv`](../data/concept_mapping.csv). Two of them
resolve the same two elements in opposite orders: `net_income` takes
`NetIncomeLoss` first, the parent's share, and `net_income_consolidated`
takes `ProfitLoss` first, the whole group's.

## Summary

| Metric | Formula | Grains | Companies with a figure at 2025-09-30 |
|---|---|---|---|
| `operating_margin_pct` | operating income / revenue | Annual, quarterly, TTM | 10 |
| `net_margin_pct` | net income / revenue | Annual, quarterly, TTM | 10 |
| `revenue_growth_yoy_pct` | revenue / revenue a year earlier - 1 | Annual, quarterly | 10 |
| `roe_pct` | TTM net income / equity at the period end | TTM | 7 |
| `debt_to_equity` | total liabilities / total equity | TTM | 7 |
| `current_ratio` | current assets / current liabilities | TTM | 10 |
| `accruals_ratio_pct` | (consolidated profit - operating cash flow) / total assets | Annual, TTM | 10 |
| `ocf_to_net_income` | operating cash flow / consolidated profit | Annual, TTM | 9 |

The last column counts the non-null values printed in [K4], [K6] and [K8],
and in [E6] for the net margin. The gaps have two causes: three companies have
negative equity, and Bloomin' made a loss.

## Profitability

### `operating_margin_pct`

`100 * operating_income / revenue`, in all three ratio views.

- **Coverage:** all ten companies on every row: 30 annual, 70 quarterly, 40
  trailing. No row is missing revenue or operating income [E6].
- **Printed by:** [R1], [R3], [R4], [K9].
- **In the ranking:** its trailing value at 2025-09-30 is the profitability
  pillar, and its nine-month change is the direction pillar (below).

### `net_margin_pct`

`100 * net_income / revenue`, in all three ratio views. `net_income` is
`NetIncomeLoss`, with `ProfitLoss` as the fallback for the two companies that
file no parent-only figure, Restaurant Brands International and Texas
Roadhouse. This is the figure the upstream project publishes, and the
reconciliation gate reproduces three of its published net margins exactly
[GATE 2].

- **Coverage:** all ten companies on every row [E6].
- **Printed by:** [GATE 2], [E2], [R1], [R3], [R4].
- **Not in the ranking.**

## Growth

### `revenue_growth_yoy_pct`

`100 * (revenue / revenue a year earlier - 1)`: against the prior fiscal year
in `ratios_annual`, against the same quarter a year earlier in
`ratios_quarterly`.

- **53-week years.** Four fiscal years in scope run 371 days
  ([`fiscal_calendar.csv`](../data/fiscal_calendar.csv)). An annual comparison
  that touches one carries `is_53_week_comparison` and a
  `revenue_growth_52wk_pct` beside it, which scales the long year by 52/53.
  Reported growth is not replaced.
- **Coverage:** 20 of 30 annual rows, FY2023 and FY2024, since FY2022 has no
  prior year in scope; 6 of the 20 are flagged 53-week [R2, R6]. 30 of 70
  quarterly rows, 2025 Q1 to Q3 [R6].
- **Printed by:** [R1], [R2], [R3], [K8].
- **In the ranking:** the nine-month version is the growth pillar (below).

## Returns and leverage

### `roe_pct`

`100 * net_income_ttm / equity at the period end`, in `ratios_ttm`.

- **The pairing rule.** The denominator follows the element the numerator
  resolved to: `StockholdersEquity` with `NetIncomeLoss`, the NCI-inclusive
  equity element with `ProfitLoss`. `roe_equity_concept` names the one used
  [GATE 6].
- **Null** unless that equity is positive. `has_negative_equity` marks the
  negative rows.
- **Thin equity.** `equity_to_assets_pct` is carried beside, and
  `is_thin_equity` is true where equity is positive but under 10% of total
  assets. Flagged rows are shown, never capped.
- **Coverage:** 40 rows, null on 12 (McDonald's, Papa John's and Yum Brands at
  four dates each) and thin on 5 (Bloomin' at 2024-12-31, Wendy's at all four)
  [R6]. At 2025-09-30, 7 of 10 have a figure [K4].
- **Sensitivity:** FY2024 over the average of opening and closing equity, the
  one date where the average exists for all ten [R5].
- **Printed by:** [GATE 6], [R4], [R5], [K6].
- **Beside the ranking, never ordering it.**

### `debt_to_equity`, with `liabilities_to_assets_pct`

`total_liabilities / total_equity`, in `ratios_ttm`, where total equity
includes noncontrolling interests wherever the company files them.
`liabilities_to_assets_pct` is `100 * total_liabilities / total_assets` and is
carried beside it.

- **Total liabilities** are reported by nine companies and derived for
  McDonald's through the balance-sheet identity with its mezzanine term
  [GATE 5, E6].
- **Null** where total equity is zero or negative. `liabilities_to_assets_pct`
  is the figure that still reads there.
- **Coverage:** `debt_to_equity` on 40 rows, null on 12 [R6], 7 of 10 at
  2025-09-30 [K4]. `liabilities_to_assets_pct` on all 40, with no input
  missing [E6].
- **Printed by:** [R4], [K2], [K6], [K7].
- **In the ranking:** `liabilities_to_assets_pct` at 2025-09-30 is the leverage
  pillar. `debt_to_equity` sits beside the ranking.

## Liquidity

### `current_ratio`

`current_assets / current_liabilities`, in `ratios_ttm`, at the four quarter
ends.

- **Coverage:** all 40 rows, with no input missing [E6].
- **Printed by:** [R4], [K6], [K7].
- **Beside the ranking, never ordering it.** Restaurants collect at the till
  and pay suppliers later, so a low ratio is not strain by itself.

## Earnings quality

Both metrics divide by `net_income_consolidated`, `ProfitLoss` first, because
operating cash flow is reported for the consolidated group.

### `accruals_ratio_pct`

`100 * (consolidated profit - operating cash flow) / total assets at the
period end`, in `earnings_quality_ttm` and `earnings_quality_annual`. The
annual view takes total assets at December 31 of the fiscal year. A negative
value means cash ran ahead of profit.

- **Coverage:** all 40 trailing rows, all 40 negative [Q4, K5]. 20 of 30
  annual rows: FY2022 is null on all ten, because the balance sheet at
  2022-12-31 is incomplete. 19 of the 20 are negative [Q4, K5].
- **Printed by:** [Q1], [Q2], [K5], [K6].
- **Beside the ranking, never ordering it.** With one sign across the group,
  it reads as a tripwire for profit running ahead of cash, not as an order.

### `ocf_to_net_income`

`operating cash flow / consolidated profit`, in the same two views.

- **Null** where consolidated profit is zero or negative.
- **Thin profit.** `is_thin_profit` is true where profit is positive but under
  1% of revenue, where the ratio divides by almost nothing. Flagged rows are
  shown.
- **Coverage:** 40 trailing rows, null on 2 (Bloomin' at 2024-12-31 and
  2025-09-30) and thin on 2 (Bloomin' at 2025-03-31 and 2025-06-30). 30 annual
  rows, null on 1 (Bloomin' FY2024) and thin on none [Q4].
- **Printed by:** [Q1], [Q2], [K6].
- **Beside the ranking, never ordering it.**

## The ranking

The view `peer_ranking` orders the ten on four pillars, all read at or up to
2025-09-30:

| Pillar | Column | Definition | Better |
|---|---|---|---|
| Profitability | `operating_margin_pct` | Trailing twelve months | Higher |
| Direction | `operating_margin_change_pts` | Operating margin over the first nine months of 2025, less the same nine months of 2024 | Higher |
| Growth | `revenue_growth_9m_pct` | Revenue over the first nine months of 2025 against the same months of 2024 | Higher |
| Leverage | `liabilities_to_assets_pct` | At 2025-09-30 | Lower |

- Each pillar is **rounded to one decimal**, then ranked 1 to 10 with
  `rank()`, so ties are shared.
- The four ranks are summed with equal weight (`rank_sum`), and `position` is
  the rank of the sum.
- `position_without_margin`, `position_without_margin_change`,
  `position_without_growth` and `position_without_leverage` re-rank the sum
  with one pillar left out.
- **Coverage:** 10 rows, no null in any pillar [K4].
- **Printed by:** [K1], [K2], [K3].

The rules, and why ranks rather than scores, are in
[`engineering-notes.md`](engineering-notes.md#the-peer-ranking-ranks-the-published-figure).

## Not computed

Three metrics are not computed. For each, the covering element reaches too few
companies:

- **interest coverage:** 1 of 10;
- **gross margin:** 4 of 10;
- **cost growth:** 4 of 10.

The measurements are in
[`concept_mapping_rationale.md`](concept_mapping_rationale.md#metrics-not-computed-each-with-the-measurement-that-rules-it-out).
