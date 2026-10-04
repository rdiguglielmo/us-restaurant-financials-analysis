-- Earnings quality: how much of the reported profit arrived as cash. Runs
-- after 01 and 02:
--
--   .venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql sql/04_earnings_quality.sql
--
-- ---------------------------------------------------------------------------
-- The definitions, and the choice behind each
-- ---------------------------------------------------------------------------
--   Profit here is net_income_consolidated: ProfitLoss where filed, otherwise
--   NetIncomeLoss. Operating cash flow is reported for the consolidated group,
--   minority shareholders included, so the profit it is compared with has to
--   be too. At 2025-09-30 the parent-only figure puts Yum China's trailing
--   profit at 904 m against 977 m consolidated, 7.5% lower, which would
--   overstate its cash conversion by 8.1%. The four companies that file no
--   ProfitLoss carry no minority interest.
--
--   accruals_ratio_pct     (profit - operating cash flow) / total assets at
--                          the period end. Negative means cash ran ahead of
--                          profit; a high positive value is profit that has
--                          not yet been collected, the pattern worth flagging.
--                          Ending assets, for the same reason ROE uses ending
--                          equity: the balance sheet a year earlier is not
--                          available at every date.
--
--   ocf_to_net_income      operating cash flow / profit. Null where profit is
--   is_thin_profit         zero or negative. Where profit is positive but
--                          under 1% of revenue the ratio divides by almost
--                          nothing: Bloomin's trailing profit of 0.3 m on
--                          3.9 bn of revenue gives 864. Those rows are
--                          flagged, shown, and do not order the ranking,
--                          the same rule as thin equity in 03.
--
-- Two grains. Trailing twelve months at the four quarter ends with a complete
-- balance sheet, which is what the ranking reads; and fiscal years 2022 to
-- 2024 for the trend, where accruals exist only for 2023 and 2024 because the
-- balance sheet at 2022-12-31 is incomplete.

-- --- EARNINGS QUALITY TTM
create or replace view earnings_quality_ttm as
select
    t.cik,
    t.company_name,
    t.period_end,
    t.net_income_consolidated_ttm                                      as profit,
    t.operating_cash_flow_ttm                                          as operating_cash_flow,
    100.0 * (t.net_income_consolidated_ttm - t.operating_cash_flow_ttm)
          / b.total_assets                                             as accruals_ratio_pct,
    case when t.net_income_consolidated_ttm > 0
         then t.operating_cash_flow_ttm / t.net_income_consolidated_ttm
    end                                                                as ocf_to_net_income,
    t.net_income_consolidated_ttm > 0
      and t.net_income_consolidated_ttm < 0.01 * t.revenue_ttm         as is_thin_profit
from flows_ttm t
join balance_quarterly b on b.cik = t.cik and b.period_end = t.period_end;

-- --- EARNINGS QUALITY ANNUAL
create or replace view earnings_quality_annual as
select
    i.cik,
    i.company_name,
    i.fiscal_year,
    i.net_income_consolidated                                          as profit,
    i.operating_cash_flow,
    100.0 * (i.net_income_consolidated - i.operating_cash_flow)
          / b.total_assets                                             as accruals_ratio_pct,
    case when i.net_income_consolidated > 0
         then i.operating_cash_flow / i.net_income_consolidated
    end                                                                as ocf_to_net_income,
    i.net_income_consolidated > 0
      and i.net_income_consolidated < 0.01 * i.revenue                 as is_thin_profit
from income_annual i
left join balance_quarterly b
       on b.cik = i.cik
      and b.period_end = make_date(cast(i.fiscal_year as integer), 12, 31);

-- --- Q1: trailing twelve months, McDonald's and Bloomin'
-- Expected, computed from the exact statement figures before this ran:
--   McDonald's 2024-12-31: accruals -2.2, OCF / profit 1.15
--   McDonald's 2025-09-30: accruals -3.4, OCF / profit 1.25
--   Bloomin' 2024-12-31:   accruals -10.4, null (loss of 122.7 m)
--   Bloomin' 2025-03-31:   accruals -6.8, 70.5, thin
--   Bloomin' 2025-06-30:   accruals -7.1, 864.2, thin
--   Bloomin' 2025-09-30:   accruals -10.1, null (loss of 52.5 m)
select
    company_name,
    period_end,
    round(accruals_ratio_pct, 1)                                       as accruals_ratio_pct,
    round(ocf_to_net_income, 2)                                        as ocf_to_net_income,
    is_thin_profit
from earnings_quality_ttm
where company_name in ('MCDONALDS CORP', 'BLOOMIN'' BRANDS, INC.')
  and (company_name = 'BLOOMIN'' BRANDS, INC.'
       or period_end in (date '2024-12-31', date '2025-09-30'))
order by company_name, period_end;

-- --- Q2: fiscal years, McDonald's and Bloomin'
-- Expected:
--   McDonald's FY2022: accruals null, OCF / profit 1.20
--              FY2023: accruals -2.0, 1.13
--              FY2024: accruals -2.2, 1.15
--   Bloomin'   FY2022: accruals null, 3.58
--              FY2023: accruals -8.1, 2.09
--              FY2024: accruals -10.4, null
select
    company_name,
    fiscal_year,
    round(accruals_ratio_pct, 1)                                       as accruals_ratio_pct,
    round(ocf_to_net_income, 2)                                        as ocf_to_net_income,
    is_thin_profit
from earnings_quality_annual
where company_name in ('MCDONALDS CORP', 'BLOOMIN'' BRANDS, INC.')
order by company_name, fiscal_year;

-- --- Q3: the consolidated profit, where it differs from the parent's
-- Expected at 2025-09-30: three companies. Yum China 977.0 against 904.0,
-- Bloomin' -52.5 against -57.7, Papa John's 38.4 against 38.3. Restaurant
-- Brands and Texas Roadhouse do not appear: their net_income already
-- resolves to ProfitLoss, so the two figures are the same.
select
    t.company_name,
    round(t.net_income_ttm / 1e6, 1)                                   as parent_profit_musd,
    round(t.net_income_consolidated_ttm / 1e6, 1)                      as consolidated_profit_musd
from flows_ttm t
where t.period_end = date '2025-09-30'
  and t.net_income_ttm <> t.net_income_consolidated_ttm
order by t.company_name;

-- --- Q4: completeness and the rows each rule nulls or flags
-- Expected: earnings_quality_ttm 40 rows, accruals on all 40, OCF / profit
-- null on 2 (Bloomin' at 2024-12-31 and 2025-09-30), thin profit on 2
-- (Bloomin' at 2025-03-31 and 2025-06-30). earnings_quality_annual 30 rows,
-- accruals null on the 10 for FY2022, OCF / profit null on 1 (Bloomin'
-- FY2024), thin profit on 0: the lowest positive year is Cheesecake FY2022
-- at 1.31% of revenue.
select 'earnings_quality_annual' as view_name, count(*) as row_count,
       count(*) filter (where accruals_ratio_pct is null) as accruals_null,
       count(*) filter (where ocf_to_net_income is null)  as ocf_to_profit_null,
       count(*) filter (where is_thin_profit)             as thin_profit
from earnings_quality_annual
union all
select 'earnings_quality_ttm', count(*),
       count(*) filter (where accruals_ratio_pct is null),
       count(*) filter (where ocf_to_net_income is null),
       count(*) filter (where is_thin_profit)
from earnings_quality_ttm
order by view_name;
