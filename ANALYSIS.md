# Financial Health of Ten Restaurant Companies: Yum China and Chipotle Lead, Bloomin' and Papa John's Trail

A position on the relative financial health of the ten restaurant companies in
scope, from what they reported to the SEC up to the quarter ended 2025-09-30,
the latest every one of them has filed. It is an analysis of reported figures,
not investment advice.

Every figure names the query that prints it. A bracketed label such as [K2] is
a section of [`sql/05_peer_ranking.sql`](sql/05_peer_ranking.sql); [R4] is a
section of [`sql/03_ratios.sql`](sql/03_ratios.sql). A figure read from a filing
names the filing, and the filings are linked at the end, with the two commands
that reproduce every labelled figure.

## The Position

**Yum China and Chipotle are the healthiest of the ten; Bloomin' Brands and
Papa John's are the weakest.** Those four places hold whichever pillar of the
ranking is left out: Yum China and Chipotle never fall below 4th, and Bloomin'
and Papa John's never rise above 9th [K3].

**The six in between are ordered by how much weight margin gets against the
balance sheet, and this document claims no more than that.** McDonald's has the
highest operating margin of the ten and the third heaviest balance sheet, and
ranks anywhere from 1st to 6th depending on which pillar is dropped [K3].

**Earnings quality does not separate these companies.** Operating cash flow
exceeds profit for all ten at each of the four trailing-twelve-month dates
[K5]. The warning signs are on the balance sheet.

| # | Company | Rank sum | Operating margin, TTM % | Margin change, 9M pts | Revenue growth, 9M % | Liabilities / assets % |
|---|---|---|---|---|---|---|
| 1 | Yum China | 15 | 10.8 (6) | +0.7 (2) | 3.1 (6) | 42.1 (1) |
| 2 | Chipotle | 17 | 16.4 (5) | -0.8 (5) | 5.6 (4) | 65.3 (3) |
| 2 | McDonald's | 17 | 46.1 (1) | +1.2 (1) | 1.8 (7) | 103.6 (8) |
| 2 | Texas Roadhouse | 17 | 8.9 (7) | -1.0 (6) | 11.7 (2) | 54.8 (2) |
| 5 | Restaurant Brands International | 18 | 23.9 (3) | -6.5 (10) | 14.0 (1) | 79.9 (4) |
| 6 | Cheesecake Factory | 21 | 5.4 (8) | +0.6 (3) | 4.9 (5) | 86.9 (5) |
| 7 | Yum Brands | 22 | 30.9 (2) | -1.4 (7) | 9.9 (3) | 204.3 (10) |
| 8 | Wendy's | 24 | 17.0 (4) | +0.6 (3) | -2.3 (10) | 97.8 (7) |
| 9 | Bloomin' Brands | 33 | 1.7 (10) | -2.5 (8) | 0.1 (9) | 89.4 (6) |
| 10 | Papa John's | 34 | 4.5 (9) | -4.2 (9) | 1.8 (7) | 147.9 (9) |

Each pillar's rank is in brackets; the position is the rank of the sum [K2].

## How the Ranking Is Built

**Four pillars, each ranked 1 to 10 and summed with equal weight.** Each one
answers a question below, and each reads for all ten companies with no null and
no flagged row [K4].

| Pillar | Measure | Better |
|---|---|---|
| Profitability | Operating margin over the twelve months to 2025-09-30 | Higher |
| Direction | Operating margin over the first nine months of 2025, less the same nine months of 2024 | Higher |
| Growth | Revenue over the first nine months of 2025 against the same months of 2024 | Higher |
| Leverage | Total liabilities over total assets at 2025-09-30 | Lower |

The nine-month window is the latest one every company files, and no 53-week
fiscal year falls inside it.

**Ranks, not z-scores.** With ten companies, one extreme sets the scale of a
z-score. Yum Brands' liabilities are 204.3% of its assets [K2], and every other
company's leverage score would be read against that figure.

**Ranked at the published precision.** Each figure is rounded to one decimal
before it is ranked, so two figures printed alike share a rank and any rank can
be recomputed from the table above. On exact values, Papa John's nine-month
growth (1,555.6 m against 1,528.6 m in its Q3 2025 10-Q, 1.7671%) would rank a
full place above McDonald's (19,877 m against 19,532 m [K1], 1.7663%) on a gap
of 0.0008 of a point. **Ties are shared**, and [K3] shows every position with each pillar
left out in turn.

**Five metrics sit beside the ranking and do not order it** [K6]:

- **Return on equity and debt to equity** are null for the three companies with
  negative book equity: McDonald's, Papa John's and Yum Brands [K4]. Wendy's
  return on equity of 170.4% rests on equity of 2.2% of its assets [R4], so it
  measures the capital structure more than the business.
- **The accruals ratio and operating cash flow over profit.** Accruals are
  negative on all 40 trailing observations [K5]: cash runs ahead of profit
  everywhere in this sector, so the level mostly measures how much depreciation
  separates the two. Ranked, the ratio rewards a fall in profit: Papa John's and
  Bloomin', 10th and 9th in the ranking, would come 1st and 2nd [K6]. It is used
  instead as a tripwire for profit running ahead of cash, under question 4.
- **Current ratio.** Texas Roadhouse has the lowest of the ten, 0.36, and the
  second lowest leverage, 54.8% [K6]. Restaurants collect at the till and pay
  suppliers later, so a low ratio is not strain by itself. Its movement is read
  under question 3.

## 1. Is Growth Sustainable?

**Revenue growth over the first nine months ran from 14.0% down to -2.3%, and
the two fastest growers include acquired restaurants.** Wendy's is the only
company whose revenue fell in every quarter of 2025 [K8].

| Company | FY2023 % | FY2024 % (52 weeks) | 2025 Q1 % | Q2 % | Q3 % | 9M 2025 % |
|---|---|---|---|---|---|---|
| Restaurant Brands International | 7.9 | 19.7 (19.7) | 21.3 | 15.9 | 6.9 | 14.0 |
| Texas Roadhouse | 15.4 | 16.0 (13.8) | 9.6 | 12.7 | 12.8 | 11.7 |
| Yum Brands | 3.4 | 6.7 (6.7) | 11.8 | 9.6 | 8.4 | 9.9 |
| Chipotle | 14.3 | 14.6 (14.6) | 6.4 | 3.0 | 7.5 | 5.6 |
| Cheesecake Factory | 4.1 | 4.1 (4.1) | 4.0 | 5.7 | 4.8 | 4.9 |
| Yum China | 14.7 | 3.0 (3.0) | 0.8 | 4.0 | 4.4 | 3.1 |
| McDonald's | 10.0 | 1.7 (1.7) | -3.5 | 5.4 | 3.0 | 1.8 |
| Papa John's | 1.6 | -3.6 (-1.7) | 0.9 | 4.2 | 0.3 | 1.8 |
| Bloomin' Brands | 4.0 | -5.2 (-3.4) | -1.8 | 0.3 | 2.1 | 0.1 |
| Wendy's | 4.1 | 3.0 (3.0) | -2.1 | -1.7 | -3.0 | -2.3 |

Source: [K8]. FY2023 on a 52-week basis differs for Cheesecake (6.1), Papa
John's (-0.3) and Bloomin' (2.0).

- **Restaurant Brands' lead is acquired, and partly debt-funded.** It bought
  Carrols, a Burger King franchisee, on 2024-05-16, with cash on hand and 750 m
  of new term-loan borrowings, and consolidates it since (Q3 2025 10-Q, Note 7).
  The quarterly profile shows the effect. Revenue grew 21.3% and 15.9% in the
  first two quarters of 2025, against a 2024 base that included Carrols only
  from mid-May. It grew 6.9% in the third quarter, when both years include it
  [K8]. Burger King China, acquired on 2025-02-14, is reported as a
  discontinued operation and is not in revenue (Note 6).
- **Texas Roadhouse grew steadily through the year**: 9.6%, 12.7% and 12.8%
  [K8]. Its filing attributes the growth to more store weeks and to comparable
  restaurant sales up 6.1% in the third quarter. The store weeks come from new
  restaurants and from franchise restaurants bought for 94.2 m (Q3 2025 10-Q).
  FY2024's 16.0% is 13.8% on a 52-week basis [K8].
- **Chipotle and Yum China are slowing.** Chipotle fell from 14.6% in FY2024
  to 5.6%, with 3.0% in the second quarter. Yum China fell from 14.7% in FY2023
  to 3.0% and then 3.1% [K8]. Yum China reports in dollars and earns in
  renminbi, so its rate includes the exchange rate, which this repository does
  not separate out.
- **McDonald's grew 1.8%**, after a first quarter 3.5% below the year before
  [K8].
- **Papa John's and Bloomin' grew 1.8% and 0.1%**, after both shrank in FY2024:
  -1.7% and -3.4% on a 52-week basis [K8].

## 2. Are Margins Improving or Deteriorating?

**Four margins improved over the first nine months and six declined, and most
of the two largest declines comes from items outside operations.** Bloomin's
decline is operational: its margin has fallen every year since FY2022 [K9],
and its third quarter was a loss even before closure charges.

| Company | FY2022 % | FY2023 % | FY2024 % | TTM 2025-09 % | 9M change, pts |
|---|---|---|---|---|---|
| McDonald's | 40.4 | 45.7 | 45.2 | 46.1 | +1.2 |
| Yum Brands | 32.0 | 32.8 | 31.8 | 30.9 | -1.4 |
| Restaurant Brands International | 29.2 | 29.2 | 28.8 | 23.9 | -6.5 |
| Wendy's | 16.9 | 17.5 | 16.5 | 17.0 | +0.6 |
| Chipotle | 13.4 | 15.8 | 16.9 | 16.4 | -0.8 |
| Yum China | 6.6 | 10.1 | 10.3 | 10.8 | +0.7 |
| Texas Roadhouse | 8.0 | 7.6 | 9.6 | 8.9 | -1.0 |
| Cheesecake Factory | 1.2 | 3.2 | 5.0 | 5.4 | +0.6 |
| Papa John's | 5.2 | 6.9 | 7.6 | 4.5 | -4.2 |
| Bloomin' Brands | 7.6 | 6.8 | 3.5 | 1.7 | -2.5 |

Source: [K9].

- **Restaurant Brands, -6.5 points.** Two items outside operations account for
  4.1 of them:
  - foreign exchange losses of 208 m in the first nine months of 2025, against
    15 m a year earlier (Q3 2025 10-Q, Note 15). That is 2.8 points on 6,968 m
    of revenue;
  - a 79 m gain on remeasuring its prior 15% stake in Carrols, booked in
    operating income in the second quarter of 2024 (Note 7). It lifts the 2024
    base by 1.3 points on 6,110 m.

  The remaining 2.4 points are not broken down here.
- **Papa John's, -4.2 points.** Its third quarter of 2024 carried a 41.3 m gain
  on the sale of its QC Center properties, recorded within general and
  administrative expenses (Q3 2025 10-Q). That gain accounts for 2.7 of the 4.2
  points (41.3 m on 1,528.6 m of nine-month 2024 revenue). The remaining 1.5
  points are still a decline.
- **Bloomin' Brands, -2.5 points**, to 1.7% over the trailing year from 7.6% in
  FY2022 [K9]. Its third quarter of 2025 closed with an operating loss of
  36.4 m. That includes 33.2 m of impairment and closure charges, mostly for
  closing 21 US restaurants and not renewing the leases of 22 more, and
  including 12.0 m for five underperforming restaurants (Q3 2025 10-Q). Before
  those charges the quarter was still a loss of 3.2 m (-36.4 + 33.2), against
  operating income of 14.2 m a year earlier (8.6 + 5.6).
- **McDonald's widened the highest margin in the group**, by 1.2 points to 46.1%
  [K9]. The other three improvements are Yum China (+0.7), Wendy's and
  Cheesecake (+0.6 each). Cheesecake's is the one that holds across every year
  the data covers: 1.2% in FY2022, 3.2%, 5.0%, and 5.4% over the trailing year.

## 3. Is There Operating Deterioration?

**The current ratio shows none. Seven of the ten rose [K7], and the two sharp
falls come from a debt maturity and from cash spent on purpose.**

- **Wendy's fell from 1.85 to 0.81**, the largest fall of the ten [K7]. Its
  current portion of long-term debt rose from 78.2 m to 425.3 m (Q3 2025 10-Q,
  Note 5). The rise is 350.7 m of Series 2019-1 Class A-2-I notes with an
  anticipated repayment date in 2026, and 49.4 m of debentures due in December
  2025, now both within twelve months. It is a financing event, not an
  operating one.
- **Texas Roadhouse fell from 0.62 to 0.36** [K7], and its current assets
  halved, from 516.6 m to 249.4 m (Q3 2025 10-Q):
  - cash fell from 245.2 m to 108.2 m, over nine months in which it spent
    94.2 m on franchise restaurants and 100.0 m on buybacks;
  - receivables fell from 193.2 m to 61.1 m.

  Its trailing operating cash flow is 0.9% lower than at the FY2024 close [K7].
- **McDonald's moved from 1.19 to 1.00** [K7]. Every other company rose.
- **Bloomin' (0.45) and Cheesecake (0.55) have the lowest ratios after Texas
  Roadhouse**, and both rose over the period, from 0.34 and 0.47 [K7].

## 4. Are There Early Signs of Risk?

**On the balance sheet, yes; in earnings quality, no.** Three companies carry
negative book equity. Wendy's combines equity of 2.2% of its assets with
shrinking revenue and rising leverage. No company reports profit running ahead
of cash.

**Leverage**

- **Negative book equity: McDonald's, Papa John's and Yum Brands** [K4], with
  liabilities at 103.6%, 147.9% and 204.3% of assets [K2]. Since the FY2024
  close, Yum Brands and McDonald's lowered that ratio, by 9.4 and 3.3 points,
  and Papa John's raised it by 1.4 [K7].
- **Wendy's is the early-warning case.** Its equity is 2.2% of assets [R4] and
  its liabilities 97.8%, up 3.0 points since the FY2024 close [K7]. Debt to
  equity is 44.57 [K6], and revenue fell in every quarter of 2025 [K8].
- **Chipotle has the largest rise in leverage, +5.0 points to 65.3%** [K7]. The
  cause is buybacks: it repurchased 1,676.1 m of stock in the first nine months
  of 2025, against 664.5 m a year earlier, which took equity from 3,655.5 m to
  3,221.8 m (Q3 2025 10-Q). It is still the third least leveraged of the ten
  [K2].
- **Bloomin's liabilities are 89.4% of assets**, 6.5 points lower than at the
  FY2024 close [K7]. Its return on equity is -16.8% on equity of 10.5% of assets
  [R4]. Part of that fall is equity recovering after the sale of its Brazil
  business, set out in [`docs/engineering-notes.md`](docs/engineering-notes.md).

**Earnings quality**

- **Profit ran ahead of cash in none of the 40 trailing observations** [K5].
  The only fiscal year of the 20 where it did is Restaurant Brands' FY2023:
  accruals of +1.7% of assets, with operating cash flow at 0.77 of profit.
- **The tripwire, profit up while cash falls between the FY2024 close and
  2025-09-30, trips once.** Texas Roadhouse's profit rose 0.4% and its cash fell
  0.9% [K7], while it still turns profit into cash at 1.67 times [K6]. The
  movement is too small to read as a signal.
- **Papa John's moves the other way**: profit down 54.3%, cash up 47.2% [K7].
  The 2024 gain from question 2 is why. Its sale proceeds were recorded as
  investing cash inflows (Q3 2025 10-Q), so the gain never entered operating
  cash flow, and its exit from the trailing window lowers profit alone.
- **Bloomin' has no ratio**: it made a loss at both dates [K4, K7].

## 5. The Ranking, Row by Row

**1. Yum China, rank sum 15.** The least leveraged of the ten, with liabilities
at 42.1% of assets, and one of four companies with a widening margin, +0.7
points to 10.8% [K2]. Its weak pillar is growth: 3.1%, after 14.7% in FY2023
[K8], at a dollar rate that includes the renminbi. It ranks 3rd without the
leverage pillar and 4th without the margin change [K3].

**2. Chipotle, 17.** No pillar ranks worse than 5th: margin 16.4%, change
-0.8, growth 5.6%, leverage 65.3% [K2]. It holds the most stable position in
the table, 2nd or 3rd under every variant [K3]. The two things to watch are
growth, down from 14.6% in FY2024 [K8], and leverage rising on buybacks
(question 4).

**2. McDonald's, 17.** It has the highest margin and the largest improvement,
46.1% and +1.2 points. Two pillars hold it back: growth of 1.8%, 7th, and
liabilities above its assets, 103.6%, 8th [K2]. It ranks 1st without the
leverage pillar and 6th without either margin pillar [K3]. It is the clearest
case of the ranking turning on how margin is weighed against the balance sheet.

**2. Texas Roadhouse, 17.** Second fastest growth, 11.7%, and second lowest
leverage, 54.8%, on a margin of 8.9% that fell 1.0 point [K2]. Part of the
growth is franchise restaurants bought back (question 1). It has the lowest
current ratio of the ten, 0.36 [K6], which is why the current ratio stays out
of the ranking. It drops to 5th without growth and 6th without leverage [K3].

**5. Restaurant Brands International, 18.** First on growth at 14.0%, and last
on margin change at -6.5 points [K2]. The Carrols acquisition and exchange
losses shape both (questions 1 and 2). Dropping growth sends it to 7th;
dropping margin change sends it to 1st [K3]. Its range and Yum Brands' are the
widest in the table.

**6. Cheesecake Factory, 21.** Mid-table on every pillar, 3rd to 8th [K2]. It
has the steadiest margin improvement of the ten, from 1.2% in FY2022 to 5.4%
[K9], and cash well ahead of profit, at 1.99 times [K6]. A thin margin and
liabilities at 86.9% of assets hold it back [K2].

**7. Yum Brands, 22.** It has the second highest margin, 30.9%, and the third
fastest growth, 9.9%, on the heaviest balance sheet in the group: liabilities
at 204.3% of assets [K2]. It rises to 2nd without the leverage pillar [K3], and
it has lowered leverage by 9.4 points since the FY2024 close [K7].

**8. Wendy's, 24.** Its margin of 17.0% widened slightly [K2]. But revenue fell
in every quarter of 2025 [K8], equity is 2.2% of assets [R4], and liquidity
fell to 0.81 as notes came within a year of repayment (question 3). It is the
early-warning case of the ten.

**9. Bloomin' Brands, 33.** Last on margin at 1.7%, and 9th on growth at 0.1%
[K2]. Its third quarter was an operating loss both before and after closure
charges (question 2). Its leverage, 89.4%, is mid-table [K2]. It ranks 9th or
10th under every variant [K3].

**10. Papa John's, 34.** It ranks 9th on margin, margin change and leverage,
and 7th on growth [K2], with liabilities at 147.9% of assets. Most of its margin
decline is a gain leaving the base (question 2), but without the margin-change
pillar it is still 9th [K3]. It ranks 9th or 10th under every variant.

## What the Ranking Claims, and What It Does Not

| Company | Full | Without margin | Without margin change | Without growth | Without leverage |
|---|---|---|---|---|---|
| Yum China | 1 | 1 | 4 | 1 | 3 |
| Chipotle | 2 | 3 | 3 | 3 | 3 |
| McDonald's | 2 | 6 | 6 | 2 | 1 |
| Texas Roadhouse | 2 | 2 | 2 | 5 | 6 |
| Restaurant Brands International | 5 | 5 | 1 | 7 | 3 |
| Cheesecake Factory | 6 | 4 | 7 | 6 | 7 |
| Yum Brands | 7 | 7 | 5 | 8 | 2 |
| Wendy's | 8 | 7 | 8 | 4 | 8 |
| Bloomin' Brands | 9 | 9 | 9 | 9 | 10 |
| Papa John's | 10 | 10 | 9 | 10 | 9 |

Source: [K3]. Each column re-ranks the sum of the other three pillars.

**The ends hold, and they are the claim.** Yum China and Chipotle stay in the
top four under every variant, and Bloomin' and Papa John's stay in the bottom
two.

**The middle six move between 1st and 8th, so their order is a statement about
weights, not about the companies.** Drop the balance sheet and McDonald's and
Yum Brands rise to 1st and 2nd. Drop the margin level and Cheesecake Factory
rises to 4th while McDonald's falls to 6th.

## Limitations

- **A snapshot at 2025-09-30.** The ranking reads four trailing-twelve-month
  dates and one nine-month window. The income statement has three annual
  points and the balance sheet two, as the
  [README](README.md#limitations) sets out.
- **Reported figures, unadjusted.** The one-off items named above stay in the
  figures the ranking reads, and the text sizes each one: Restaurant Brands'
  exchange losses and Carrols gain, Papa John's property gain, and Bloomin's
  closure charges.
- **Only the filings listed below were read.** Growth is split into acquired
  and organic only for the two companies whose filings were read for it.
- **Currency.** Yum China earns in renminbi and reports in dollars. Its growth
  and margins include the exchange rate.
- **53 weeks.** Texas Roadhouse's FY2024 ran 53 weeks, so its trailing flows at
  2025-09-30 also cover 53 weeks. That lifts its return on equity by about 0.6
  points but not its margins, where both sides of the ratio cover the same
  weeks. The nine-month window holds no 53-week year.
- **Ten companies under two SIC codes**, 5810 and 5812, treated as one
  industry.
- **Not investment advice.**

## Sources and Reproduction

The Q3 2025 quarterly reports read for this document, as filed with the SEC:

- [Restaurant Brands International](https://www.sec.gov/Archives/edgar/data/1618756/000161875625000300/qsr-20250930.htm)
- [Papa John's](https://www.sec.gov/Archives/edgar/data/901491/000162828025049845/pzza-20250928.htm)
- [Wendy's](https://www.sec.gov/Archives/edgar/data/30697/000003069725000039/wen-20250928.htm)
- [Bloomin' Brands](https://www.sec.gov/Archives/edgar/data/1546417/000154641725000141/blmn-20250928.htm)
- [Texas Roadhouse](https://www.sec.gov/Archives/edgar/data/1289460/000110465925108178/txrh-20250930x10q.htm)
- [Chipotle](https://www.sec.gov/Archives/edgar/data/1058090/000105809025000088/cmg-20250930.htm)

Every bracketed figure is printed by these two commands. The first proves that
the inputs reproduce the upstream project's published figures. The second
prints each cited section with its expected answer above its result.

```
.venv/Scripts/python src/query.py sql/00_reconciliation_gate.sql
.venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql sql/03_ratios.sql sql/04_earnings_quality.sql sql/05_peer_ranking.sql
```
