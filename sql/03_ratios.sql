-- Ratios: profitability, growth, return on equity, leverage and liquidity, on
-- the grains 02_financial_statements.sql builds. Runs after 01 and 02:
--
--   .venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql sql/03_ratios.sql
--
-- ---------------------------------------------------------------------------
-- The definitions, and the choice behind each
-- ---------------------------------------------------------------------------
--   operating_margin_pct   operating income / revenue
--   net_margin_pct         net income / revenue, net income parent-first as
--                          upstream publishes it
--
--   revenue_growth_yoy_pct Reported, against the prior fiscal year or the
--                          same quarter a year earlier. Four fiscal years in
--                          scope run 53 weeks (data/fiscal_calendar.csv), so
--                          an annual comparison touching one is flagged and
--                          carried beside a 52-week equivalent that scales the
--                          53-week year by 52/53. That is an approximation:
--                          the extra week is not an average week. Calendar
--                          years of 366 days are not adjusted (0.3%).
--
--   roe_pct                Trailing-twelve-month net income over equity at
--                          the period end. The denominator follows the
--                          element the numerator resolved to: NetIncomeLoss
--                          with StockholdersEquity, ProfitLoss with the
--                          NCI-inclusive element. Null where that equity is
--                          negative. The average of opening and closing
--                          equity exists for all ten only at 2024-12-31, so
--                          it is computed there once, as a sensitivity.
--
--   equity_to_assets_pct   The ROE denominator over total assets. Under 10%,
--   is_thin_equity         ROE measures the capital structure more than the
--                          business: the row is flagged, shown, never capped.
--
--   debt_to_equity         Total liabilities over TOTAL equity, including
--   liabilities_to_assets  noncontrolling interests where filed: minority
--                          capital is equity, not debt. Null where total
--                          equity is negative; liabilities_to_assets is the
--                          figure that still reads there.
--
--   current_ratio          current assets / current liabilities
--
-- Texas Roadhouse's FY2024 runs 53 weeks, so its derived Q4 2024 covers 14
-- and each of its trailing twelve months 53. Its TTM flows run about 1.9%
-- high. Declared here, not adjusted.

-- --- RATIOS ANNUAL
create or replace view ratios_annual as
with sized as (
    select
        i.*,
        k.days,
        lag(i.revenue) over (partition by i.cik order by i.fiscal_year) as prior_revenue,
        lag(k.days)    over (partition by i.cik order by i.fiscal_year) as prior_days
    from income_annual i
    join fiscal_calendar k on k.cik = i.cik and k.fiscal_year = i.fiscal_year
)
select
    cik,
    company_name,
    fiscal_year,
    100.0 * operating_income / revenue                                 as operating_margin_pct,
    100.0 * net_income / revenue                                       as net_margin_pct,
    100.0 * (revenue / prior_revenue - 1)                              as revenue_growth_yoy_pct,
    prior_revenue is not null and (days = 371 or prior_days = 371)     as is_53_week_comparison,
    100.0 * ((revenue       * case when days       = 371 then 52.0 / 53 else 1 end)
           / (prior_revenue * case when prior_days = 371 then 52.0 / 53 else 1 end)
           - 1)                                                        as revenue_growth_52wk_pct
from sized;

-- --- RATIOS QUARTERLY
create or replace view ratios_quarterly as
select
    q.cik,
    q.company_name,
    q.period_end,
    q.calendar_year,
    q.calendar_quarter,
    q.is_derived,
    100.0 * q.operating_income / q.revenue                             as operating_margin_pct,
    100.0 * q.net_income / q.revenue                                   as net_margin_pct,
    100.0 * (q.revenue / p.revenue - 1)                                as revenue_growth_yoy_pct
from income_quarterly q
left join income_quarterly p
       on p.cik = q.cik
      and p.period_end = cast(q.period_end - interval 1 year as date);

-- --- RATIOS TTM
create or replace view ratios_ttm as
with paired as (
    select
        t.*,
        b.total_assets,
        b.current_assets,
        b.current_liabilities,
        b.total_liabilities,
        case when t.net_income_tag = 'ProfitLoss'
             then b.stockholders_equity_incl_nci
             else b.stockholders_equity end                            as roe_equity,
        case when t.net_income_tag = 'ProfitLoss'
             then 'stockholders_equity_incl_nci'
             else 'stockholders_equity' end                            as roe_equity_concept,
        coalesce(b.stockholders_equity_incl_nci, b.stockholders_equity) as total_equity
    from flows_ttm t
    join balance_quarterly b on b.cik = t.cik and b.period_end = t.period_end
)
select
    cik,
    company_name,
    period_end,
    100.0 * operating_income_ttm / revenue_ttm                         as operating_margin_pct,
    100.0 * net_income_ttm / revenue_ttm                               as net_margin_pct,
    case when roe_equity > 0
         then 100.0 * net_income_ttm / roe_equity end                  as roe_pct,
    roe_equity_concept,
    100.0 * roe_equity / total_assets                                  as equity_to_assets_pct,
    roe_equity > 0 and roe_equity < 0.10 * total_assets                as is_thin_equity,
    roe_equity < 0                                                     as has_negative_equity,
    case when total_equity > 0
         then total_liabilities / total_equity end                     as debt_to_equity,
    100.0 * total_liabilities / total_assets                           as liabilities_to_assets_pct,
    current_assets / current_liabilities                               as current_ratio
from paired;

-- --- R1: annual ratios, McDonald's and Bloomin'
-- Expected, FY2024 then FY2023:
--   McDonald's: operating margin 45.2 / 45.7, net margin 31.7 / 33.2,
--     growth 1.7 / 10.0, the same at 52 weeks, not flagged.
--   Bloomin': operating margin 3.5 / 6.8, net margin -3.2 / 5.9,
--     growth -5.2 / 4.0 reported, -3.4 / 2.0 at 52 weeks, both flagged.
select
    company_name,
    fiscal_year,
    round(operating_margin_pct, 1)                                     as operating_margin_pct,
    round(net_margin_pct, 1)                                           as net_margin_pct,
    round(revenue_growth_yoy_pct, 1)                                   as growth_reported_pct,
    round(revenue_growth_52wk_pct, 1)                                  as growth_52wk_pct,
    is_53_week_comparison
from ratios_annual
where company_name in ('MCDONALDS CORP', 'BLOOMIN'' BRANDS, INC.')
  and fiscal_year >= 2023
order by company_name, fiscal_year desc;

-- --- R2: every annual comparison that touches a 53-week year
-- Expected: six rows, reported then 52-week growth:
--   Bloomin' FY2023 4.0 / 2.0, FY2024 -5.2 / -3.4
--   Cheesecake FY2023 4.1 / 6.1
--   Papa John's FY2023 1.6 / -0.3, FY2024 -3.6 / -1.7
--   Texas Roadhouse FY2024 16.0 / 13.8
select
    company_name,
    fiscal_year,
    round(revenue_growth_yoy_pct, 1)                                   as growth_reported_pct,
    round(revenue_growth_52wk_pct, 1)                                  as growth_52wk_pct
from ratios_annual
where is_53_week_comparison
order by company_name, fiscal_year;

-- --- R3: quarterly ratios at 2025 Q3
-- Expected: McDonald's operating margin 47.4, net 32.2, growth 3.0;
-- Bloomin' operating margin -3.9, net -4.9, growth 2.1. The net margins are
-- GATE 2's.
select
    company_name,
    round(operating_margin_pct, 1)                                     as operating_margin_pct,
    round(net_margin_pct, 1)                                           as net_margin_pct,
    round(revenue_growth_yoy_pct, 1)                                   as growth_yoy_pct
from ratios_quarterly
where period_end = date '2025-09-30'
  and company_name in ('MCDONALDS CORP', 'BLOOMIN'' BRANDS, INC.')
order by company_name;

-- --- R4: trailing-twelve-month ratios
-- Expected at 2025-09-30:
--   McDonald's: operating margin 46.1, net 32.0, ROE null (negative equity),
--     debt_to_equity null, liabilities_to_assets 103.6, current ratio 1.00.
--   Bloomin': operating margin 1.7, net -1.5, ROE -16.8 on 10.5% equity to
--     assets, not thin, debt_to_equity 8.4, liabilities_to_assets 89.4,
--     current ratio 0.45.
--   Restaurant Brands: debt_to_equity 3.97, on total equity.
--   Wendy's: ROE about 170, thin.
-- And Bloomin' at 2024-12-31: ROE -94.5, GATE 6's figure, thin at 4.0%.
select
    company_name,
    period_end,
    round(operating_margin_pct, 1)                                     as op_margin_pct,
    round(net_margin_pct, 1)                                           as net_margin_pct,
    round(roe_pct, 1)                                                  as roe_pct,
    round(equity_to_assets_pct, 1)                                     as equity_to_assets_pct,
    is_thin_equity,
    round(debt_to_equity, 2)                                           as debt_to_equity,
    round(liabilities_to_assets_pct, 1)                                as liab_to_assets_pct,
    round(current_ratio, 2)                                            as current_ratio
from ratios_ttm
where (period_end = date '2025-09-30'
       and company_name in ('MCDONALDS CORP', 'BLOOMIN'' BRANDS, INC.',
                            'RESTAURANT BRANDS INTERNATIONAL INC.', 'WENDY''S CO'))
   or (period_end = date '2024-12-31' and company_name = 'BLOOMIN'' BRANDS, INC.')
order by company_name, period_end;

-- --- R5: ROE on average equity, FY2024 only
-- The sensitivity for the choice of ending equity. Expected: Chipotle 45.7,
-- Cheesecake 41.2, Texas Roadhouse 35.1, Restaurant Brands 30.2, Wendy's
-- 68.3, Yum China 15.0, Bloomin' -47.0; null for the three with negative
-- equity. ending_equity_roe_pct is GATE 6's column.
-- The expectation first written here said 41.3 and 68.2. It was computed from
-- inputs rounded to the million, and on equity of a few hundred million that
-- moves the first decimal: 157 / avg(318, 443) is 41.26, while the exact
-- 156.783 / avg(318.062, 443.455) is 41.18.
with equity as (
    select
        i.company_name,
        i.net_income,
        case when i.net_income_tag = 'ProfitLoss'
             then b.stockholders_equity_incl_nci
             else b.stockholders_equity end                            as equity,
        b.period_end
    from income_annual i
    join balance_quarterly b
      on b.cik = i.cik and b.period_end in (date '2023-12-31', date '2024-12-31')
    where i.fiscal_year = 2024
)
select
    company_name,
    case when min(equity) > 0
         then round(100.0 * max(net_income) / avg(equity), 1) end      as average_equity_roe_pct,
    case when min(equity) > 0
         then round(100.0 * max(net_income)
                    / max(equity) filter (where period_end = date '2024-12-31'), 1)
    end                                                                as ending_equity_roe_pct
from equity
group by company_name
order by company_name;

-- --- R6: completeness and the rows each rule nulls or flags
-- Expected: ratios_annual 30 rows, 20 with growth, 6 of them flagged 53-week;
-- ratios_quarterly 70 rows, 30 with growth (2025 Q1 to Q3); ratios_ttm 40
-- rows, ROE null on 12 and debt_to_equity null on 12 (McDonald's, Papa
-- John's and Yum Brands at four dates each), thin equity on 5 (Bloomin' at
-- 2024-12-31, Wendy's at all four).
select 'ratios_annual' as view_name, count(*) as row_count,
       count(revenue_growth_yoy_pct) as with_growth,
       count(*) filter (where is_53_week_comparison) as flagged_53_week,
       null as roe_null, null as debt_to_equity_null, null as thin_equity
from ratios_annual
union all
select 'ratios_quarterly', count(*), count(revenue_growth_yoy_pct), null, null, null, null
from ratios_quarterly
union all
select 'ratios_ttm', count(*), null, null,
       count(*) filter (where roe_pct is null),
       count(*) filter (where debt_to_equity is null),
       count(*) filter (where is_thin_equity)
from ratios_ttm
order by view_name;
