-- Peer ranking: the ten companies ordered by financial health on four pillars,
-- with the metrics that do not order it carried beside. Runs after 01 to 04:
--
--   .venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql sql/03_ratios.sql sql/04_earnings_quality.sql sql/05_peer_ranking.sql
--
-- The four positions and the taxonomy-version tie-break are taken once, in 01.
-- This file reads only the views 02, 03 and 04 create.
--
-- ---------------------------------------------------------------------------
-- The pillars, and the choice behind each
-- ---------------------------------------------------------------------------
--   operating_margin_pct         Trailing twelve months at 2025-09-30. The
--                                level of profitability.
--
--   operating_margin_change_pts  Operating margin over the first nine months
--                                of 2025 less the same nine months of 2024.
--                                The direction. It orders the ten exactly as
--                                the change in trailing margin since
--                                2024-12-31 does.
--
--   revenue_growth_9m_pct        Revenue over the first nine months of 2025
--                                against 2024: the latest window every company
--                                files, and no 53-week year falls inside it.
--
--   liabilities_to_assets_pct    At 2025-09-30, lower is better. The one
--                                leverage figure that reads for all ten: three
--                                carry negative equity, so debt_to_equity is
--                                null for them.
--
-- Each pillar is ranked 1 to 10 and the four ranks are summed with equal
-- weight. Ranks rather than z-scores: with ten companies a single extreme sets
-- the scale, and Yum Brands' liabilities are 204% of its assets.
--
-- Ranked on the figure rounded to one decimal, the precision it is published
-- at, so that two figures printed alike share a rank and every rank can be
-- recomputed from the published table. On exact values Papa John's 9M growth
-- of 1.76708% would rank a full place above McDonald's 1.76633%, a gap of
-- 0.0008 of a point. Ties are shared, rank() rather than row_number(), and K3
-- shows how far each position moves when one pillar is left out.
--
-- ---------------------------------------------------------------------------
-- Beside the ranking, never ordering it
-- ---------------------------------------------------------------------------
--   roe_pct, debt_to_equity      Null for the three companies with negative
--                                equity, and ROE is thin-equity flagged for
--                                Wendy's.
--
--   accruals_ratio_pct,          Accruals are negative on all 40 trailing rows
--   ocf_to_net_income            (K5): cash runs ahead of profit everywhere,
--                                because depreciation is large in this sector.
--                                Ranked, the ratio rewards a fall in profit:
--                                Papa John's and Bloomin' would lead (K6). It
--                                is read as a tripwire, profit ahead of cash,
--                                not as an order.
--
--   current_ratio                Restaurants collect at the till and pay
--                                suppliers later. Texas Roadhouse has the
--                                lowest, 0.36, with the second lowest
--                                liabilities to assets (K6).

-- --- PEER RANKING INPUTS
create or replace view peer_ranking_inputs as
with nine_months as (
    select
        cik,
        sum(revenue)          filter (where calendar_year = 2025)        as revenue_2025,
        sum(revenue)          filter (where calendar_year = 2024)        as revenue_2024,
        sum(operating_income) filter (where calendar_year = 2025)        as operating_income_2025,
        sum(operating_income) filter (where calendar_year = 2024)        as operating_income_2024
    from income_quarterly
    where calendar_quarter <= 3
    group by cik
)
select
    r.cik,
    r.company_name,
    round(r.operating_margin_pct, 1)                                   as operating_margin_pct,
    round(100.0 * n.operating_income_2025 / n.revenue_2025
        - 100.0 * n.operating_income_2024 / n.revenue_2024, 1)         as operating_margin_change_pts,
    round(100.0 * (n.revenue_2025 / n.revenue_2024 - 1), 1)            as revenue_growth_9m_pct,
    round(r.liabilities_to_assets_pct, 1)                              as liabilities_to_assets_pct,
    round(r.roe_pct, 1)                                                as roe_pct,
    r.is_thin_equity,
    r.has_negative_equity,
    round(r.debt_to_equity, 2)                                         as debt_to_equity,
    round(r.current_ratio, 2)                                          as current_ratio,
    round(q.accruals_ratio_pct, 1)                                     as accruals_ratio_pct,
    round(q.ocf_to_net_income, 2)                                      as ocf_to_net_income,
    q.is_thin_profit
from ratios_ttm r
join earnings_quality_ttm q on q.cik = r.cik and q.period_end = r.period_end
join nine_months n          on n.cik = r.cik
where r.period_end = date '2025-09-30';

-- --- PEER RANKING
create or replace view peer_ranking as
with ranked as (
    select
        *,
        rank() over (order by operating_margin_pct desc)               as operating_margin_rank,
        rank() over (order by operating_margin_change_pts desc)        as margin_change_rank,
        rank() over (order by revenue_growth_9m_pct desc)              as growth_rank,
        rank() over (order by liabilities_to_assets_pct asc)           as leverage_rank
    from peer_ranking_inputs
),
summed as (
    select
        *,
        operating_margin_rank + margin_change_rank
          + growth_rank + leverage_rank                                as rank_sum
    from ranked
)
select
    rank() over (order by rank_sum)                                    as position,
    *,
    -- The sensitivity K3 prints: each position re-ranked on the sum of the
    -- other three pillars. Carried in the view so the exported ranking and
    -- K3 read the same four columns.
    rank() over (order by rank_sum - operating_margin_rank)            as position_without_margin,
    rank() over (order by rank_sum - margin_change_rank)               as position_without_margin_change,
    rank() over (order by rank_sum - growth_rank)                      as position_without_growth,
    rank() over (order by rank_sum - leverage_rank)                    as position_without_leverage
from summed;

-- --- K1: the four pillars for three companies, computed by hand
-- Expected, from the exact statement figures in millions:
-- McDonald's: margin 12,105 / 26,264 = 46.1; change 9,237 / 19,877 less
-- 8,844 / 19,532 = +1.2; growth 19,877 / 19,532 - 1 = 1.8; liabilities
-- 62,771 / 60,608 = 103.6. Ranks 1, 1, 7, 8, sum 17.
-- Bloomin': 66.658 / 3,952.793 = 1.7; 50.461 / 2,980.773 less
-- 123.611 / 2,978.455 = -2.5; 2,980.773 / 2,978.455 - 1 = 0.1;
-- 2,932.056 / 3,280.063 = 89.4. Ranks 10, 8, 9, 6, sum 33.
-- Yum China: 1,254 / 11,569 = 10.8; 1,103 / 8,974 less 1,011 / 8,708 = +0.7;
-- 8,974 / 8,708 - 1 = 3.1; 4,648 / 11,034 = 42.1. Ranks 6, 2, 6, 1, sum 15.
select
    company_name,
    operating_margin_pct,
    operating_margin_change_pts,
    revenue_growth_9m_pct,
    liabilities_to_assets_pct,
    operating_margin_rank,
    margin_change_rank,
    growth_rank,
    leverage_rank,
    rank_sum
from peer_ranking
where company_name in ('MCDONALDS CORP', 'BLOOMIN'' BRANDS, INC.', 'YUM CHINA HOLDINGS, INC.')
order by company_name;

-- --- K2: the ranking
-- Expected, position and rank sum:
-- 1 Yum China 15; 2 Chipotle, Texas Roadhouse and McDonald's 17;
-- 5 Restaurant Brands 18; 6 Cheesecake 21; 7 Yum Brands 22; 8 Wendy's 24;
-- 9 Bloomin' 33; 10 Papa John's 34.
-- Two ties come from the rounding: McDonald's and Papa John's share growth
-- rank 7 at 1.8, Wendy's and Cheesecake share margin-change rank 3 at 0.6.
select
    position,
    company_name,
    rank_sum,
    operating_margin_pct,
    operating_margin_rank,
    operating_margin_change_pts,
    margin_change_rank,
    revenue_growth_9m_pct,
    growth_rank,
    liabilities_to_assets_pct,
    leverage_rank
from peer_ranking
order by position, company_name;

-- --- K3: sensitivity, the position with one pillar left out
-- Each column re-ranks the sum of the other three pillars. Expected, full /
-- without margin / without margin change / without growth / without leverage:
-- Yum China 1/1/4/1/3, Chipotle 2/3/3/3/3, Texas Roadhouse 2/2/2/5/6,
-- McDonald's 2/6/6/2/1, Restaurant Brands 5/5/1/7/3, Cheesecake 6/4/7/6/7,
-- Yum Brands 7/7/5/8/2, Wendy's 8/7/8/4/8, Bloomin' 9/9/9/9/10,
-- Papa John's 10/10/9/10/9.
-- What holds under every variant: Yum China and Chipotle never fall below 4th,
-- Bloomin' and Papa John's never rise above 9th. The middle six range from
-- 1st to 8th.
select
    company_name,
    position                                                           as full_position,
    position_without_margin                                            as without_margin,
    position_without_margin_change                                     as without_margin_change,
    position_without_growth                                            as without_growth,
    position_without_leverage                                          as without_leverage
from peer_ranking
order by position, company_name;

-- --- K4: completeness, and the beside columns that are null or flagged
-- Expected: 10 rows, no null in any of the four pillars. Beside: ROE null on
-- 3 and debt_to_equity null on the same 3 (McDonald's, Papa John's, Yum
-- Brands, negative equity), OCF / profit null on 1 (Bloomin', a loss), thin
-- equity on 1 (Wendy's), thin profit on 0.
select
    count(*)                                                           as row_count,
    count(*) filter (where operating_margin_pct is null
                        or operating_margin_change_pts is null
                        or revenue_growth_9m_pct is null
                        or liabilities_to_assets_pct is null)          as pillar_nulls,
    count(*) filter (where roe_pct is null)                            as roe_null,
    count(*) filter (where debt_to_equity is null)                     as debt_to_equity_null,
    count(*) filter (where ocf_to_net_income is null)                  as ocf_to_profit_null,
    count(*) filter (where is_thin_equity)                             as thin_equity,
    count(*) filter (where is_thin_profit)                             as thin_profit,
    string_agg(company_name, '; ' order by company_name)
        filter (where has_negative_equity)                             as negative_equity
from peer_ranking;

-- --- K5: accruals are negative everywhere
-- Expected: trailing twelve months, 40 rows with accruals, 40 negative.
-- Fiscal years, 20 rows with accruals (FY2023 and FY2024), 19 negative; the
-- one that is not is Restaurant Brands FY2023, +1.7, with OCF / profit 0.77.
select
    'earnings_quality_ttm'                                             as view_name,
    count(accruals_ratio_pct)                                          as rows_with_accruals,
    count(*) filter (where accruals_ratio_pct < 0)                     as negative,
    string_agg(company_name || ' ' || period_end || ' '
               || round(accruals_ratio_pct, 1) || ' / '
               || round(ocf_to_net_income, 2), '; ')
        filter (where accruals_ratio_pct >= 0)                         as not_negative
from earnings_quality_ttm
union all
select
    'earnings_quality_annual',
    count(accruals_ratio_pct),
    count(*) filter (where accruals_ratio_pct < 0),
    string_agg(company_name || ' FY' || fiscal_year || ' '
               || round(accruals_ratio_pct, 1) || ' / '
               || round(ocf_to_net_income, 2), '; ')
        filter (where accruals_ratio_pct >= 0)
from earnings_quality_annual
order by view_name;

-- --- K6: the columns beside the ranking, and what two would do as pillars
-- Expected at 2025-09-30. Ranked on accruals, lowest first, the order opens
-- with Papa John's -13.4, Bloomin' -10.1 and Texas Roadhouse -9.2: the two
-- the ranking puts last would come first, because a fall in profit drives
-- the ratio down. Ranked on current ratio, Texas Roadhouse comes last at
-- 0.36 while its leverage rank is 2, at 54.8.
-- The rest, as profiled before this file was written. ROE: Chipotle 47.7,
-- Cheesecake 37.8, Texas Roadhouse 30.2, Restaurant Brands 24.8, Yum China
-- 15.9, Bloomin' -16.8, Wendy's 170.4 flagged thin; null for McDonald's,
-- Papa John's and Yum Brands. Debt to equity: Yum China 0.73, Texas Roadhouse
-- 1.21, Chipotle 1.88, Restaurant Brands 3.97, Cheesecake 6.62, Bloomin'
-- 8.43, Wendy's 44.57; null for the same three. OCF / profit: Papa John's
-- 4.08, Cheesecake 1.99, Wendy's 1.85, Texas Roadhouse 1.67, Yum China 1.54,
-- Chipotle 1.44, Yum Brands 1.32, Restaurant Brands 1.28, McDonald's 1.25;
-- null for Bloomin'.
select
    position,
    company_name,
    roe_pct,
    is_thin_equity,
    debt_to_equity,
    current_ratio,
    rank() over (order by current_ratio desc)                          as current_ratio_rank,
    accruals_ratio_pct,
    rank() over (order by accruals_ratio_pct asc)                      as accruals_rank,
    ocf_to_net_income,
    liabilities_to_assets_pct,
    leverage_rank
from peer_ranking
order by accruals_rank;

-- --- K7: the movement since the FY2024 close
-- From 2024-12-31 to 2025-09-30. Expected, computed from the exact statement
-- figures:
-- Liabilities to assets, points: Chipotle +5.0, Wendy's +3.0, Cheesecake
-- +1.5, Papa John's +1.4; Yum China -0.1, Restaurant Brands -0.5, Texas
-- Roadhouse -2.1, McDonald's -3.3, Bloomin' -6.5, Yum Brands -9.4.
-- Current ratio: Wendy's 1.85 to 0.81, -1.04, the largest fall; Texas
-- Roadhouse -0.26, McDonald's -0.19; the other seven rise.
-- Consolidated profit against operating cash flow, % change: Papa John's
-- -54.3 / +47.2, Restaurant Brands -11.3 / +9.1, Wendy's -4.3 / -3.2,
-- Yum Brands -2.6 / +12.8, Yum China -0.3 / +6.3, Chipotle +0.2 / +5.2,
-- Texas Roadhouse +0.4 / -0.9, McDonald's +2.3 / +11.0, Cheesecake
-- +2.6 / +19.4. Bloomin' profit change null: a loss at both dates, and a
-- percentage of a negative base means nothing. Its cash flow +21.6.
-- Profit up with cash down on exactly one row: Texas Roadhouse.
with d0 as (
    select r.cik, r.liabilities_to_assets_pct, r.current_ratio,
           q.profit, q.operating_cash_flow
    from ratios_ttm r
    join earnings_quality_ttm q on q.cik = r.cik and q.period_end = r.period_end
    where r.period_end = date '2024-12-31'
),
d1 as (
    select r.cik, r.company_name, r.liabilities_to_assets_pct, r.current_ratio,
           q.profit, q.operating_cash_flow
    from ratios_ttm r
    join earnings_quality_ttm q on q.cik = r.cik and q.period_end = r.period_end
    where r.period_end = date '2025-09-30'
)
select
    d1.company_name,
    round(d1.liabilities_to_assets_pct - d0.liabilities_to_assets_pct, 1)
                                                                       as liabilities_to_assets_change_pts,
    round(d0.current_ratio, 2)                                         as current_ratio_2024_12,
    round(d1.current_ratio, 2)                                         as current_ratio_2025_09,
    round(d1.current_ratio - d0.current_ratio, 2)                      as current_ratio_change,
    case when d0.profit > 0
         then round(100.0 * (d1.profit / d0.profit - 1), 1) end        as profit_change_pct,
    case when d0.operating_cash_flow > 0
         then round(100.0 * (d1.operating_cash_flow
                             / d0.operating_cash_flow - 1), 1) end     as cash_flow_change_pct,
    d0.profit > 0
      and d1.profit > d0.profit
      and d1.operating_cash_flow < d0.operating_cash_flow              as is_profit_up_cash_down
from d1
join d0 on d0.cik = d1.cik
order by d1.company_name;

-- --- K8: growth over every horizon the data carries
-- The growth pillar is the last column. Expected, as profiled before this
-- file was written: FY2023 reported / 52 weeks, FY2024 reported / 52 weeks,
-- 2025 Q1, Q2, Q3, nine months:
-- Restaurant Brands 7.9/7.9, 19.7/19.7, 21.3, 15.9, 6.9, 14.0
-- Texas Roadhouse 15.4/15.4, 16.0/13.8, 9.6, 12.7, 12.8, 11.7
-- Yum Brands 3.4/3.4, 6.7/6.7, 11.8, 9.6, 8.4, 9.9
-- Chipotle 14.3/14.3, 14.6/14.6, 6.4, 3.0, 7.5, 5.6
-- Cheesecake 4.1/6.1, 4.1/4.1, 4.0, 5.7, 4.8, 4.9
-- Yum China 14.7/14.7, 3.0/3.0, 0.8, 4.0, 4.4, 3.1
-- McDonald's 10.0/10.0, 1.7/1.7, -3.5, 5.4, 3.0, 1.8
-- Papa John's 1.6/-0.3, -3.6/-1.7, 0.9, 4.2, 0.3, 1.8
-- Bloomin' 4.0/2.0, -5.2/-3.4, -1.8, 0.3, 2.1, 0.1
-- Wendy's 4.1/4.1, 3.0/3.0, -2.1, -1.7, -3.0, -2.3
with annual as (
    select
        cik,
        max(revenue_growth_yoy_pct)  filter (where fiscal_year = 2023)   as fy2023,
        max(revenue_growth_52wk_pct) filter (where fiscal_year = 2023)   as fy2023_52wk,
        max(revenue_growth_yoy_pct)  filter (where fiscal_year = 2024)   as fy2024,
        max(revenue_growth_52wk_pct) filter (where fiscal_year = 2024)   as fy2024_52wk
    from ratios_annual
    group by cik
),
quarterly as (
    select
        cik,
        max(revenue_growth_yoy_pct) filter (where calendar_quarter = 1)  as q1,
        max(revenue_growth_yoy_pct) filter (where calendar_quarter = 2)  as q2,
        max(revenue_growth_yoy_pct) filter (where calendar_quarter = 3)  as q3
    from ratios_quarterly
    where calendar_year = 2025
    group by cik
)
select
    p.position,
    p.company_name,
    round(a.fy2023, 1)                                                 as fy2023_pct,
    round(a.fy2023_52wk, 1)                                            as fy2023_52wk_pct,
    round(a.fy2024, 1)                                                 as fy2024_pct,
    round(a.fy2024_52wk, 1)                                            as fy2024_52wk_pct,
    round(q.q1, 1)                                                     as q1_2025_pct,
    round(q.q2, 1)                                                     as q2_2025_pct,
    round(q.q3, 1)                                                     as q3_2025_pct,
    p.revenue_growth_9m_pct                                            as nine_months_2025_pct
from peer_ranking p
join annual a    on a.cik = p.cik
join quarterly q on q.cik = p.cik
order by p.revenue_growth_9m_pct desc, p.company_name;

-- --- K9: operating margin over every horizon the data carries
-- The margin pillars are the last two columns. Expected, as profiled before
-- this file was written: FY2022, FY2023, FY2024, trailing twelve months at
-- 2025-09-30, nine-month change:
-- McDonald's 40.4, 45.7, 45.2, 46.1, +1.2
-- Yum Brands 32.0, 32.8, 31.8, 30.9, -1.4
-- Restaurant Brands 29.2, 29.2, 28.8, 23.9, -6.5
-- Wendy's 16.9, 17.5, 16.5, 17.0, +0.6
-- Chipotle 13.4, 15.8, 16.9, 16.4, -0.8
-- Yum China 6.6, 10.1, 10.3, 10.8, +0.7
-- Texas Roadhouse 8.0, 7.6, 9.6, 8.9, -1.0
-- Cheesecake 1.2, 3.2, 5.0, 5.4, +0.6
-- Papa John's 5.2, 6.9, 7.6, 4.5, -4.2
-- Bloomin' 7.6, 6.8, 3.5, 1.7, -2.5
with annual as (
    select
        cik,
        max(operating_margin_pct) filter (where fiscal_year = 2022)     as fy2022,
        max(operating_margin_pct) filter (where fiscal_year = 2023)     as fy2023,
        max(operating_margin_pct) filter (where fiscal_year = 2024)     as fy2024
    from ratios_annual
    group by cik
)
select
    p.position,
    p.company_name,
    round(a.fy2022, 1)                                                 as fy2022_pct,
    round(a.fy2023, 1)                                                 as fy2023_pct,
    round(a.fy2024, 1)                                                 as fy2024_pct,
    p.operating_margin_pct                                             as ttm_2025_09_pct,
    p.operating_margin_change_pts                                      as change_9m_pts
from peer_ranking p
join annual a on a.cik = p.cik
order by p.operating_margin_pct desc;
