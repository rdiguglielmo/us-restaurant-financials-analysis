# Engineering Notes

The rules in this repository that are easy to break and expensive to break.
[`README.md`](../README.md) says what the project is;
[`concept_mapping_rationale.md`](concept_mapping_rationale.md) says why each
accounting element maps where it does.

## Four positions every query must take, and a fifth the flags do not cover

The upstream fact table carries three flags because three properties of SEC
data produce a total larger than the truth **without anything failing**.
Ignoring a single one makes a total 2.21 times too large.

| Position | What it prevents |
|---|---|
| `is_consolidated = true` | Segment breakdowns repeat the company total: 11,362 of 22,604 facts |
| `is_latest_report = true` | Figures superseded by a later filing: 1,840 of 22,604 |
| `is_year_to_date = false` | Half-year and nine-month rows sit beside the quarters they contain: 5,135 of 22,604 |
| `unit_of_measure = 'USD'` | Share counts share the column with dollars: 1,166 facts |

**The fifth is not a flag, and it is this project's own finding.**
`dim_account` is grained on `(tag_name, tag_version)`, not on the concept name.
A company that files the same concept under two taxonomy years produces two
rows that are distinct economic facts upstream and survive all four positions
above. Joining `dim_account` on `tag_name` without a tie-break duplicates:
**465 of 6,717 company / concept / periods, 6.9%, worst case four rows for one
figure.**

In 464 of those the two versions carry the same value, which is what makes it
dangerous — it looks harmless until it is not. In one they disagree:
Cheesecake Factory's current contract liability at 2024-06-30, **192.3 m
against 226.8 m, a 17.9% gap** that a `max()` would have resolved silently and
in favour of the larger figure.

**So every resolution orders by `tag_preference`, then `tag_version`
descending.** GATE 7 re-measures the duplication on every run, so a change to
the upstream export cannot widen it quietly.

## The balance sheet does not close without the mezzanine term

```
liabilities = assets - equity_incl_nci - redeemable_nci
```

Redeemable noncontrolling interest is carried outside permanent equity and
outside liabilities both. Dropping the term understates derived liabilities by
13 m for Yum China and 0.9 m for Papa John's wherever they carry it. GATE 5
proves the corrected identity closes to the cent on all nine companies that
report `Liabilities` directly, which is what licenses deriving it for the tenth.

## Return on equity pairs its own denominator

`ProfitLoss` includes noncontrolling interests, `StockholdersEquity` excludes
them, and pairing across that boundary overstates the ratio. The denominator
follows whichever element the numerator resolved to. Detail and the 56% figure
behind it are in the rationale.

## Coverage is measured with the flags applied, never raw

A raw fact count is mostly segment detail. Counting companies per element
before applying the flags reported 7 for the preferred revenue element where
the usable figure is 4, and 6 for cost of revenue where it is 4. Every coverage
number quoted in this repository is the flagged one.

## Grain

Income-statement concepts have three complete fiscal years (2022 to 2024) for
all ten companies. **Balance-sheet concepts are complete only from
2023-12-31**, so ratios that use them are carried quarterly, where 2024-12-31
through 2025-09-30 gives four points across all ten companies.

`sql/02_financial_statements.sql` builds one view per grain the data supports:

| View | Grain | Rows |
|---|---|---|
| `income_annual` | FY2022 to FY2024 | 30 |
| `income_quarterly` | 2024-Q1 to 2025-Q3, discrete, Q4 2024 derived | 70 |
| `balance_quarterly` | 2023-12-31, 2024-12-31 and the three 2025 quarter ends | 50 |
| `flows_ttm` | Trailing twelve months at the four quarter ends with a complete balance sheet | 40 |

## Cash flow is filed year to date

**Operating cash flow is discrete only for the first quarter.** The second and
third quarters are filed as six- and nine-month years to date; only McDonald's
files them discretely. A coverage count of "companies with a quarterly cash
flow" therefore reports 10 while meaning "a first quarter": nine companies
have no discrete cash flow after March. Cash flow is used annually and as a
trailing twelve months, never as a discrete quarter.

## The fourth quarter is full year less nine months

The fourth quarter is never filed on its own. It is derived as **full year less
the nine-month year to date**, one subtraction between two filed figures,
rather than full year less three quarters. Each filer rounds every cumulative
figure on its own, so its filed quarters need not add to its filed year to
date: McDonald's, reporting in millions, differs by 1 m between the two routes;
Chipotle, reporting in thousands, by 2 thousand. Bloomin', the one company that
also files a discrete fourth quarter, matches the derived figure exactly.

## Trailing twelve months, so that a flow can meet a stock

```
TTM(d) = FY2024 - YTD(d less one year) + YTD(d)
```

with the year to date whose length matches the quarter (three, six or nine
months), and TTM at 2024-12-31 equal to FY2024. It lets a flow be divided by a
balance at the same date without annualising a single quarter, which in a
seasonal business would carry the season into the ratio.

## One revenue line under two element names

Cheesecake Factory presents revenue as
`RevenueFromContractWithCustomerExcludingAssessedTax` in its 10-K and as
`…IncludingAssessedTax` in its 10-Qs, so its derived fourth quarter and its
2025 trailing twelve months subtract one element from the other. **It is the
same line.** The company tags every figure under both elements with identical
values: SEC's element history carries 3,581,699,000 for FY2024 and
2,660,736,000 for the first nine months of 2024 under each. The upstream fact
table keeps the element the statement presents, which is why only one appears
per filing here. `flows_ttm.pieces_with_mixed_tags` counts these rows, and
they are the only three.

## Return on equity: trailing twelve months over ending equity

**ROE is trailing-twelve-month net income over equity at the period end**, at
the four quarter ends from 2024-12-31. The textbook average of opening and
closing equity needs equity a year earlier, and `StockholdersEquity` at the
2024 first to third quarter ends is missing for 6 of the 10 companies, so the
average exists only at 2024-12-31. It is computed there once, as a
sensitivity: it moves Bloomin' from -94.5% to -47.0% and Chipotle from 42.0% to
45.7%.

**Thin equity is shown and flagged, never capped.** Where equity is below 10%
of total assets, ROE measures the capital structure more than the business:
Wendy's equity is 2.2% of its assets at 2025-09-30, which puts its ROE near
171%. Those rows carry `equity_to_assets` and `is_thin_equity`, stay visible,
and do not order the ranking. Negative equity still returns null.

Bloomin's 2024-12-31 equity of 135.5 m is partly an artifact of the sale of its
Brazil business. The Q1 2025 10-Q reclassifies 217.5 m of foreign currency
translation losses into earnings "due to sale of business" against a reported
gain of 2.9 m on the sale, and equity is back at 380.6 m by 2025-03-31.

## Leverage divides by total equity

`debt_to_equity` is total liabilities over **total equity, noncontrolling
interests included** where the company files them: minority capital is equity,
not debt, and it is the same term the liabilities identity already uses.
Dividing by the parent's equity alone would put Restaurant Brands at 6.06
instead of 3.97 at 2025-09-30, because 1.8 bn of minority capital would count
as neither. Where total equity is negative the ratio is null and
`liabilities_to_assets` is the figure that still reads.

ROE keeps its own denominator (the pairing rule above), so the project carries
two equity figures on purpose: the one that matches the numerator's scope for
a return, and the whole of equity for a capital structure.

## Earnings quality compares cash with consolidated profit

Operating cash flow is consolidated, so `accruals_ratio` and
`ocf_to_net_income` divide by `net_income_consolidated`, a concept that
resolves `ProfitLoss` before `NetIncomeLoss`. The rationale has the evidence
that the fallback is safe. It is the reason Bloomin's parent profit and its
consolidated profit can differ in sign at the same date: at 2025-03-31 the
first is -2.0 m (ROE -0.5%) and the second +3.2 m.

**A profit near zero is flagged the way thin equity is.** Where consolidated
profit is positive but under 1% of revenue, `ocf_to_net_income` divides by
almost nothing: Bloomin's trailing profit of 0.3 m on 3.9 bn of revenue gives
864. `is_thin_profit` marks the two rows where that happens; they stay visible
and do not order the ranking. The lowest positive profit that is not flagged
is Papa John's at 1.84% of revenue.

## Four fiscal years run 53 weeks

Four of the thirty fiscal years in scope are 371 days long: Cheesecake FY2022,
Papa John's FY2023, Bloomin' FY2023 and Texas Roadhouse FY2024. **The upstream
tables cannot show it:** period ends are normalised to the calendar quarter and
no period start is kept. The lengths come from SEC's period dates and live in
[`../data/fiscal_calendar.csv`](../data/fiscal_calendar.csv), one row per
company and year with the accession of a 10-K that reports the period.
Cheesecake's three rows cite its FY2024 10-K, the first to present revenue
under the element it resolves to, which carries all three years.

`ratios_annual` keeps reported growth, flags the six comparisons that touch a
53-week year, and carries a 52-week equivalent that scales the long year by
52/53. The largest correction is Texas Roadhouse FY2024, 16.0% reported against
13.8%. It is an approximation, since the extra week is not an average week, and
calendar years of 366 days are left alone (0.3%).

The 53rd week also reaches the quarterly grain. Texas Roadhouse's derived Q4
2024 covers 14 weeks and each of its trailing twelve months 53, so its TTM
flows run about 1.9% high and its ROE about 0.6 points high. Declared, not
adjusted.

## The peer ranking ranks the published figure

`sql/05_peer_ranking.sql` orders the ten on four pillars that read for all ten
with no null and no flag: operating margin over the trailing twelve months, its
change over the first nine months of 2025 against 2024, revenue growth over the
same window, and liabilities over assets. Each is ranked 1 to 10 and the four
ranks are summed with equal weight. Ranks rather than z-scores, because with
ten companies one extreme sets the scale: Yum Brands' liabilities are 204% of
its assets.

**Each pillar is rounded to one decimal before it is ranked.** On exact values
Papa John's nine-month growth of 1.76708% outranks McDonald's 1.76633% by
0.0008 of a point, which is a full place in the rank and a point in the sum.
Rounded, both print 1.8 and share rank 7. Ranking the figure as published is
what lets a reader recompute every rank from the published table.

**Ties are shared**, `rank()` and never `row_number()`: three companies share
second place. Section K3 re-ranks with each pillar left out in turn, and the
analysis claims only what holds under every variant.

**Five metrics sit beside the ranking and never order it.** Return on equity
and debt to equity are null for the three companies with negative equity. The
accruals ratio is negative on all 40 trailing rows, so ranked it rewards a fall
in profit and puts the two weakest companies first. The current ratio is low
by business model: Texas Roadhouse's is the lowest, 0.36, with the second
lowest leverage.

**A percentage change on a negative base is null.** Bloomin' lost money at
both ends of the comparison in K7, and -52.5 m on -122.7 m computes as a 57%
fall when the loss in fact narrowed.

## The dashboard reads one exported file

`src/export.py` is the only script that writes. It runs `01` to `05` on one
connection, so every check prints again, then copies the `peer_ranking` view,
with the short company name from `data/company_names.csv`, to
`output/peer_ranking.parquet`. The Power BI model reads that file and computes
nothing: each measure returns one value of one row. The ranking has one
implementation, the SQL, and the page cannot disagree with it.

```
.venv/Scripts/python src/export.py
```

**`output/`, not `data/`.** The runner registers everything under `data/` as an
input view, so a ranking written there would be read back as an input under
the name of the view `05` creates.

**Parquet, not CSV.** The file carries its types and the model's columns take
them unchanged. A CSV is typed again by Power Query under the machine's
locale, where `10.8` can be read as 108 without an error.

**Sorted before it is written, checked after.** The rows are ordered by
position and name, so the same data gives the same bytes: two runs produce the
same SHA-256, and the file's history in git changes only when the ranking does.
The checks read the written file, not the query that wrote it: 10 rows, 25
columns, no column whose type differs from the view's.

**The sensitivity lives in the view.** The four positions with one pillar left
out are columns of `peer_ranking`, and K3 prints them from there, so the file
the page reads and the table the analysis cites come from the same
expressions.

## Running a query

There is no database to build and no ingestion to run. The runner opens DuckDB
in memory, registers one view per Parquet file in `data/parquet/` and one per
CSV in `data/` (the concept mapping, the fiscal calendar and the company short
names, with `cik` read as text so it keeps its leading zeros), and prints the
result:

```
.venv/Scripts/python src/query.py sql/00_reconciliation_gate.sql
.venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql
.venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql sql/03_ratios.sql sql/04_earnings_quality.sql sql/05_peer_ranking.sql
.venv/Scripts/python src/query.py "select * from dim_company"
```

Given a `.sql` file it runs each section marked `-- --- NAME` in turn and
prints the comment lines beneath the marker above the result. That is how each
gate states its expected answer before showing the actual one. A section that
creates a view is executed and reported by name.

**Several files run in the order given, on one connection.** `01` creates
`resolved_facts`, `02` builds the statements on it, and each later file is
invoked after the ones it reads. There is no persisted database, so every
upstream check runs again whenever a downstream file does.

**The gate runs before any figure here is trusted.** This project recalculates
over a warehouse it did not build, so reproducing that project's published
figures is what stands in place of a quality layer of its own. If a result
disagrees with its expectation, the expectation does not get adjusted.
