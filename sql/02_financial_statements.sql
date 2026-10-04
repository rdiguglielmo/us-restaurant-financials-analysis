-- Normalised statements: one row per company and period, one column per
-- concept, on the grains the data actually supports. Reads resolved_facts, so
-- it runs after 01:
--
--   .venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql
--
-- ---------------------------------------------------------------------------
-- The grains, and why there are four
-- ---------------------------------------------------------------------------
--   income_annual       FY2022 to FY2024. Annual facts exist for three years
--                       and no more.
--
--   income_quarterly    2024-Q1 to 2025-Q3, discrete. The fourth quarter is
--                       never filed on its own, so Q4 2024 is derived as the
--                       full year less the nine-month year to date, and
--                       flagged. Full year less the three quarters would be
--                       three subtractions of rounded figures instead of one:
--                       McDonald's reports in millions and the two routes
--                       differ by 1 m. Operating cash flow is not on this
--                       grain: it is filed year to date, discrete only for the
--                       first quarter.
--
--   balance_quarterly   Five instants, the only ones complete for all ten:
--                       2023-12-31, 2024-12-31 and the three 2025 quarter
--                       ends. The 2024 quarter ends survive only as partial
--                       comparatives in equity statements.
--
--   flows_ttm           Trailing twelve months at the four quarter ends that
--                       have a complete balance sheet, so that a flow and a
--                       stock can be divided without annualising a quarter:
--                         TTM(d) = FY2024 - YTD(d less one year) + YTD(d)
--                       and at 2024-12-31 TTM is FY2024 itself.
--
-- No query here sums across durations. Every source row is selected by an
-- explicit period_length_qtrs, which is the position this file takes on
-- is_year_to_date.
--
-- Pivots take max(value) filter (where concept = ...). resolved_facts holds
-- one row per company, concept, period end and duration (01, CHECK 1), so the
-- max() selects that row; it never chooses between two.

-- --- INCOME ANNUAL
create or replace view income_annual as
select
    cik,
    company_name,
    year(period_end)                                                   as fiscal_year,
    max(value)    filter (where concept = 'revenue')                   as revenue,
    max(value)    filter (where concept = 'operating_income')          as operating_income,
    max(value)    filter (where concept = 'net_income')                as net_income,
    max(value)    filter (where concept = 'operating_cash_flow')       as operating_cash_flow,
    max(value)    filter (where concept = 'net_income_consolidated')   as net_income_consolidated,
    max(tag_name) filter (where concept = 'revenue')                   as revenue_tag,
    max(tag_name) filter (where concept = 'net_income')                as net_income_tag
from resolved_facts
where period_length_qtrs = 4
  and period_end in (date '2022-12-31', date '2023-12-31', date '2024-12-31')
group by cik, company_name, period_end;

-- --- INCOME QUARTERLY
create or replace view income_quarterly as
with filed as (
    select cik, company_name, concept, period_end, value, tag_name,
           false as is_derived
    from resolved_facts
    where period_length_qtrs = 1
      and concept in ('revenue', 'operating_income', 'net_income')
      and period_end between date '2024-03-31' and date '2025-09-30'
      and month(period_end) <> 12
),
q4_derived as (
    select fy.cik, fy.company_name, fy.concept, fy.period_end,
           fy.value - ytd.value as value,
           fy.tag_name,
           true as is_derived
    from resolved_facts fy
    join resolved_facts ytd
      on ytd.cik                = fy.cik
     and ytd.concept            = fy.concept
     and ytd.period_length_qtrs = 3
     and ytd.period_end         = date '2024-09-30'
    where fy.period_length_qtrs = 4
      and fy.period_end         = date '2024-12-31'
      and fy.concept in ('revenue', 'operating_income', 'net_income')
),
long as (
    select * from filed
    union all
    select * from q4_derived
)
select
    cik,
    company_name,
    period_end,
    year(period_end)                                                   as calendar_year,
    quarter(period_end)                                                as calendar_quarter,
    max(value)    filter (where concept = 'revenue')                   as revenue,
    max(value)    filter (where concept = 'operating_income')          as operating_income,
    max(value)    filter (where concept = 'net_income')                as net_income,
    max(tag_name) filter (where concept = 'revenue')                   as revenue_tag,
    max(tag_name) filter (where concept = 'net_income')                as net_income_tag,
    bool_or(is_derived)                                                as is_derived
from long
group by cik, company_name, period_end;

-- --- BALANCE QUARTERLY
-- Total liabilities is reported by nine companies and derived for the tenth
-- through the identity GATE 5 proves on the nine:
--   liabilities = assets - equity_incl_nci - redeemable_nci
-- with equity_incl_nci falling back to stockholders_equity where a company
-- files no minority interest, which is McDonald's case.
create or replace view balance_quarterly as
with pivoted as (
    select
        cik,
        company_name,
        period_end,
        max(value) filter (where concept = 'total_assets')                 as total_assets,
        max(value) filter (where concept = 'current_assets')               as current_assets,
        max(value) filter (where concept = 'current_liabilities')          as current_liabilities,
        max(value) filter (where concept = 'total_liabilities')            as liabilities_reported,
        max(value) filter (where concept = 'stockholders_equity')          as stockholders_equity,
        max(value) filter (where concept = 'stockholders_equity_incl_nci') as stockholders_equity_incl_nci,
        max(value) filter (where concept = 'redeemable_nci')               as redeemable_nci
    from resolved_facts
    where period_length_qtrs = 0
      and period_end in (date '2023-12-31', date '2024-12-31', date '2025-03-31',
                         date '2025-06-30', date '2025-09-30')
    group by cik, company_name, period_end
)
select
    cik,
    company_name,
    period_end,
    total_assets,
    current_assets,
    current_liabilities,
    coalesce(liabilities_reported,
             total_assets
             - coalesce(stockholders_equity_incl_nci, stockholders_equity)
             - coalesce(redeemable_nci, 0))                            as total_liabilities,
    liabilities_reported is null                                       as is_liabilities_derived,
    stockholders_equity,
    stockholders_equity_incl_nci,
    redeemable_nci
from pivoted;

-- --- FLOWS TTM
create or replace view flows_ttm as
with fy as (
    select cik, company_name, concept, value, tag_name
    from resolved_facts
    where period_length_qtrs = 4
      and period_end = date '2024-12-31'
      and concept in ('revenue', 'operating_income', 'net_income', 'operating_cash_flow',
                      'net_income_consolidated')
),
ytd as (
    -- The year to date whose length matches its quarter: three months at Q1,
    -- six at Q2, nine at Q3. McDonald's discrete Q2 and Q3 cash flow is not
    -- a year to date and is left out by the second condition.
    select cik, concept, period_end, period_length_qtrs, value, tag_name
    from resolved_facts
    where concept in ('revenue', 'operating_income', 'net_income', 'operating_cash_flow',
                      'net_income_consolidated')
      and period_length_qtrs in (1, 2, 3)
      and period_length_qtrs = quarter(period_end)
      and period_end between date '2024-03-31' and date '2025-09-30'
),
long as (
    select cik, company_name, concept, date '2024-12-31' as period_end,
           value, tag_name, tag_name as tag_prior_ytd, tag_name as tag_current_ytd
    from fy
    union all
    select fy.cik, fy.company_name, fy.concept, cur.period_end,
           fy.value - prior.value + cur.value,
           fy.tag_name, prior.tag_name, cur.tag_name
    from fy
    join ytd cur
      on cur.cik = fy.cik and cur.concept = fy.concept
     and year(cur.period_end) = 2025
    join ytd prior
      on prior.cik                = cur.cik
     and prior.concept            = cur.concept
     and prior.period_length_qtrs = cur.period_length_qtrs
     and prior.period_end         = cast(cur.period_end - interval 1 year as date)
)
select
    cik,
    company_name,
    period_end,
    max(value)    filter (where concept = 'revenue')                   as revenue_ttm,
    max(value)    filter (where concept = 'operating_income')          as operating_income_ttm,
    max(value)    filter (where concept = 'net_income')                as net_income_ttm,
    max(value)    filter (where concept = 'operating_cash_flow')       as operating_cash_flow_ttm,
    max(value)    filter (where concept = 'net_income_consolidated')   as net_income_consolidated_ttm,
    max(tag_name) filter (where concept = 'net_income')                as net_income_tag,
    -- A TTM is three filed figures. If they resolved to different elements,
    -- the sum may mix definitions. E5 counts them and E3 explains the three
    -- that exist.
    count(*) filter (where tag_name <> tag_prior_ytd
                        or tag_name <> tag_current_ytd)                as pieces_with_mixed_tags
from long
group by cik, company_name, period_end;

-- --- E1: FY2024 against GATE 3
-- Expected, identical row by row to GATE 3: operating margin 45.2 McDonald's,
-- 31.8 Yum Brands, 28.8 Restaurant Brands, 16.9 Chipotle, 16.5 Wendy's,
-- 10.3 Yum China, 9.6 Texas Roadhouse, 7.6 Papa John's, 5.0 Cheesecake,
-- 3.5 Bloomin'. Revenue summed over the ten: 81.70 B.
select
    company_name,
    round(revenue / 1e9, 2)                                            as revenue_busd,
    round(100.0 * operating_income / revenue, 1)                       as operating_margin_pct,
    round(sum(revenue) over () / 1e9, 2)                               as revenue_all_ten_busd
from income_annual
where fiscal_year = 2024
order by operating_margin_pct desc;

-- --- E2: 2025 Q3 against GATE 2
-- Expected, identical to GATE 2: net margin 32.2 McDonald's, 20.1 Yum Brands,
-- 17.8 Restaurant Brands, 12.7 Chipotle, 8.8 Yum China, 8.1 Wendy's,
-- 5.9 Texas Roadhouse, 3.5 Cheesecake, 0.9 Papa John's, -4.9 Bloomin'.
-- ProfitLoss for Restaurant Brands and Texas Roadhouse, NetIncomeLoss for
-- the other eight.
select
    company_name,
    round(100.0 * net_income / revenue, 1)                             as net_margin_pct,
    net_income_tag
from income_quarterly
where period_end = date '2025-09-30'
order by net_margin_pct desc;

-- --- E3: Q4 2024 by both routes
-- The view derives Q4 as full year less nine months. The other route is full
-- year less the three filed quarters. Only rows that differ are listed.
-- Expected: three rows.
--   McDonald's net income, -1 m, and Chipotle revenue, -0.002 m: rounding at
--     the reporting unit. Each filer rounds every cumulative figure on its
--     own, so its filed quarters need not add to its filed year to date.
--     McDonald's reports in millions, Chipotle in thousands.
--   Cheesecake revenue, difference 0, tags_differ true. Its 10-K presents
--     revenue as ...ExcludingAssessedTax and its 10-Qs as
--     ...IncludingAssessedTax, but it tags every figure under both elements
--     with identical values: the SEC element history carries 3,581,699,000
--     for FY2024 and 2,660,736,000 for the nine months under each. The mix is
--     one line under two names, not two definitions.
-- The expectation first written here was "McDonald's only, and no row where
-- the elements differ". It came from profiling net income alone, which is how
-- a check on three concepts ended up with an expectation measured on one.
with fy_less_quarters as (
    select fy.cik, fy.concept,
           fy.value - sum(q.value) as q4_via_quarters
    from resolved_facts fy
    join resolved_facts q
      on q.cik = fy.cik and q.concept = fy.concept
     and q.period_length_qtrs = 1
     and q.period_end in (date '2024-03-31', date '2024-06-30', date '2024-09-30')
    where fy.period_length_qtrs = 4
      and fy.period_end = date '2024-12-31'
      and fy.concept in ('revenue', 'operating_income', 'net_income')
    group by fy.cik, fy.concept, fy.value
),
nine_month_tags as (
    select fy.cik, fy.concept, fy.tag_name as fy_tag, ytd.tag_name as ytd_tag
    from resolved_facts fy
    join resolved_facts ytd
      on ytd.cik = fy.cik and ytd.concept = fy.concept
     and ytd.period_length_qtrs = 3 and ytd.period_end = date '2024-09-30'
    where fy.period_length_qtrs = 4 and fy.period_end = date '2024-12-31'
),
view_q4 as (
    unpivot (
        select cik, company_name, revenue, operating_income, net_income
        from income_quarterly
        where period_end = date '2024-12-31'
    )
    on revenue, operating_income, net_income
    into name concept value q4_via_nine_months
)
select
    v.company_name,
    v.concept,
    round((v.q4_via_nine_months - b.q4_via_quarters) / 1e6, 3)         as difference_musd,
    t.fy_tag <> t.ytd_tag                                              as tags_differ
from view_q4 v
join fy_less_quarters b on b.cik = v.cik and b.concept = v.concept
join nine_month_tags  t on t.cik = v.cik and t.concept = v.concept
where v.q4_via_nine_months <> b.q4_via_quarters
   or t.fy_tag <> t.ytd_tag
order by v.company_name, v.concept;

-- --- E4: the one filed fourth quarter
-- Bloomin' is the only company that files a discrete Q4 2024, for revenue and
-- operating income. The derived figure must equal it.
-- Expected: two rows, difference 0 on both.
select
    q.company_name,
    r.concept,
    round(r.value / 1e6, 3)                                            as filed_q4_musd,
    round(case r.concept when 'revenue' then q.revenue
                         else q.operating_income end / 1e6, 3)         as derived_q4_musd,
    case r.concept when 'revenue' then q.revenue
                   else q.operating_income end - r.value               as difference
from resolved_facts r
join income_quarterly q
  on q.cik = r.cik and q.period_end = r.period_end
where r.period_length_qtrs = 1
  and r.period_end = date '2024-12-31'
order by r.concept;

-- --- E5: TTM at 2025-09-30 by both routes
-- The view uses the nine-month years to date. The other route adds the four
-- discrete quarters, Q4 2024 derived plus the three filed 2025 quarters.
-- Only rows that differ are listed.
-- Expected: one row, McDonald's, revenue -1 m, the same rounding as E3.
-- mixed_tag_pieces_all_rows 3: Cheesecake revenue at the three 2025 quarter
-- ends, where the FY2024 piece was presented under the other element. E3
-- explains why that is one line under two names.
-- The expectation first written here was 0 mixed pieces, for the same reason
-- as E3's.
with four_quarters as (
    select cik,
           sum(revenue)          as revenue,
           sum(operating_income) as operating_income,
           sum(net_income)       as net_income
    from income_quarterly
    where period_end between date '2024-12-31' and date '2025-09-30'
    group by cik
)
select
    t.company_name,
    round((t.revenue_ttm          - f.revenue)          / 1e6, 3)      as revenue_difference_musd,
    round((t.operating_income_ttm - f.operating_income) / 1e6, 3)      as operating_income_difference_musd,
    round((t.net_income_ttm       - f.net_income)       / 1e6, 3)      as net_income_difference_musd,
    (select sum(pieces_with_mixed_tags) from flows_ttm)                as mixed_tag_pieces_all_rows
from flows_ttm t
join four_quarters f on f.cik = t.cik
where t.period_end = date '2025-09-30'
  and (t.revenue_ttm          <> f.revenue
    or t.operating_income_ttm <> f.operating_income
    or t.net_income_ttm       <> f.net_income)
order by t.company_name;

-- --- E7: three figures read from the filing documents, not from XBRL
-- The Parquet and the SEC XBRL API are the same source, so this check reads
-- the rendered filings instead. Expected:
--   McDonald's total liabilities at 2024-12-31, derived: 58,979 m. The 10-K
--     balance sheet has no total liabilities line; it shows total liabilities
--     and shareholders' equity (deficit) of 55,182 and a deficit of (3,797).
--   McDonald's Q4 2024 revenue, derived: 6,388 m, the Q4 total revenues in
--     the earnings release furnished on 8-K, exhibit 99.1, 2025-02-10.
--   Bloomin' stockholders' equity: 135.510 m at 2024-12-31 (10-K) and
--     380.597 m at 2025-03-31 (Q1 10-Q). Period ends are normalised: the
--     filings date them 2024-12-29 and 2025-03-30.
select 'McDonald''s total liabilities 2024-12-31 (derived)' as figure,
       58979.0 as filing_musd,
       round(total_liabilities / 1e6, 3) as computed_musd
from balance_quarterly
where company_name = 'MCDONALDS CORP' and period_end = date '2024-12-31'
union all
select 'McDonald''s revenue Q4 2024 (derived)', 6388.0, round(revenue / 1e6, 3)
from income_quarterly
where company_name = 'MCDONALDS CORP' and period_end = date '2024-12-31'
union all
select 'Bloomin'' stockholders equity ' || strftime(period_end, '%Y-%m-%d'),
       case period_end when date '2024-12-31' then 135.510 else 380.597 end,
       round(stockholders_equity / 1e6, 3)
from balance_quarterly
where company_name = 'BLOOMIN'' BRANDS, INC.'
  and period_end in (date '2024-12-31', date '2025-03-31')
order by figure;

-- --- E6: completeness
-- Expected: income_annual 30 rows, income_quarterly 70, balance_quarterly 50,
-- flows_ttm 40, and 0 rows with a null in any column a ratio will divide by.
-- total_liabilities derived on exactly 5 rows, all McDonald's.
select 'income_annual' as view_name, count(*) as row_count,
       count(*) filter (where revenue is null or operating_income is null
                           or net_income is null or operating_cash_flow is null
                           or net_income_consolidated is null) as rows_with_nulls,
       null as liabilities_derived_rows, null as liabilities_derived_companies
from income_annual
union all
select 'income_quarterly', count(*),
       count(*) filter (where revenue is null or operating_income is null or net_income is null),
       null, null
from income_quarterly
union all
select 'balance_quarterly', count(*),
       count(*) filter (where total_assets is null or current_assets is null
                           or current_liabilities is null or total_liabilities is null
                           or stockholders_equity is null),
       count(*) filter (where is_liabilities_derived),
       string_agg(distinct company_name, ', ') filter (where is_liabilities_derived)
from balance_quarterly
union all
select 'flows_ttm', count(*),
       count(*) filter (where revenue_ttm is null or operating_income_ttm is null
                           or net_income_ttm is null or operating_cash_flow_ttm is null
                           or net_income_consolidated_ttm is null),
       null, null
from flows_ttm
order by view_name;
