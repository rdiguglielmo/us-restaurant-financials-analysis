-- Concept resolution. Turns the upstream fact table into one figure per
-- company, business concept, period end and duration, and names the element
-- that supplied it. Every later file reads the view this one creates:
--
--   .venv/Scripts/python src/query.py sql/01_concept_resolution.sql
--
-- ---------------------------------------------------------------------------
-- The positions taken, and why
-- ---------------------------------------------------------------------------
--   is_consolidated = true     Segment breakdowns share tag, period and unit
--                              with the company total.
--
--   is_latest_report = true    A later filing supersedes the comparative an
--                              earlier one carried.
--
--   unit_of_measure = 'USD'    Share counts share the value column.
--
--   is_year_to_date            KEPT, deliberately, and labelled by
--                              period_length_qtrs: 2 is a half year, 3 nine
--                              months. The fourth quarter and the trailing
--                              twelve months are derived from them in
--                              02_financial_statements.sql, and operating
--                              cash flow is filed discretely only for the
--                              first quarter, so without the year-to-date rows
--                              there is no cash flow after March. No query may
--                              sum across durations; every consumer selects
--                              one period_length_qtrs explicitly.
--
--   tag_version                The fifth position. dim_account is grained on
--                              (tag_name, tag_version), so a concept filed
--                              under two taxonomy years survives every flag
--                              above twice. Resolution orders by
--                              tag_preference, then tag_version descending.
--
-- Concepts come from data/concept_mapping.csv. No tag list is hardcoded here.

-- --- RESOLVED FACTS
create or replace view resolved_facts as
select
    c.cik,
    c.company_name,
    m.concept,
    f.period_end_key      as period_end,
    f.period_length_qtrs,
    f.value,
    m.tag_name,
    m.tag_preference,
    a.tag_version
from fct_financial_facts f
join dim_company     c on c.company_key = f.company_key
join dim_account     a on a.account_key = f.account_key
join concept_mapping m on m.tag_name    = a.tag_name
where f.is_consolidated
  and f.is_latest_report
  and f.unit_of_measure = 'USD'
  and f.value is not null
qualify row_number() over (
    partition by c.cik, m.concept, f.period_end_key, f.period_length_qtrs
    order by m.tag_preference, a.tag_version desc
) = 1;

-- --- CHECK 1: one figure per company, concept, period end and duration
-- Expected: duplicate_keys 0. The qualify above guarantees it; this check is
-- here so that a later edit to the view cannot quietly break it.
select
    count(*)                                                        as resolved_rows,
    count(distinct (cik, concept, period_end, period_length_qtrs))  as distinct_keys,
    count(*) - count(distinct (cik, concept, period_end, period_length_qtrs)) as duplicate_keys
from resolved_facts;

-- --- CHECK 2: companies reached per concept, duration and period end
-- Expected, from 2022-12 on, identical to the matrix profiled before this file
-- was written. The rows that decide the design of the statements:
--   income concepts, q=1: 10 at 2024-03 to 2024-09 and 2025-03 to 2025-09;
--     revenue and operating_income also 1 (Bloomin') at the 2023 quarters.
--   operating_cash_flow, q=1: 10 at the first quarters, 1 at Q2 and Q3.
--     Cash flow is filed year to date, so only McDonald's has a discrete
--     second and third quarter. q=2 and q=3 reach 10.
--   q=4, every duration concept: 10 at 2022-12, 2023-12 and 2024-12.
--   total_assets, current assets and liabilities, stockholders_equity:
--     10 at 2023-12, 2024-12 and the three 2025 quarter ends.
--   total_liabilities: 9 at those same five instants.
--   net_income_consolidated: identical to net_income on every row. It
--     resolves the same two elements in the opposite order, so it reaches
--     the same companies at the same periods.
-- Any other count means the view resolves differently from the profile.
pivot (
    select concept, period_length_qtrs as q, strftime(period_end, '%y-%m') as pe, cik
    from resolved_facts
    where period_end >= date '2022-12-31'
)
on pe using count(distinct cik)
group by concept, q
order by concept, q;

-- --- CHECK 3: one resolution, every candidate it chose from
-- Cheesecake Factory's net income for the first quarter of 2025, a key where
-- the preference and the version tie-break both act.
-- Expected: 7 facts, all 32.941 m. Three not consolidated: a column of the
-- equity statement, not the company total. One superseded: ProfitLoss in the
-- Q2 10-Q, filed again in the Q3 10-Q. Of the three left, net_income takes
-- NetIncomeLoss and net_income_consolidated takes ProfitLoss at us-gaap/2025,
-- the newer of its two versions.
select
    a.tag_name,
    a.tag_version,
    d.fiscal_period || ' ' || d.form_type                              as filed_in,
    f.is_consolidated,
    f.is_latest_report,
    round(f.value / 1e6, 3)                                            as value_musd,
    (select string_agg(r.concept, ', ' order by r.concept)
       from resolved_facts r
      where f.is_consolidated and f.is_latest_report
        and r.cik = c.cik
        and r.period_end = f.period_end_key
        and r.period_length_qtrs = f.period_length_qtrs
        and r.tag_name = a.tag_name
        and r.tag_version = a.tag_version
        and r.concept in ('net_income', 'net_income_consolidated'))   as taken_for
from fct_financial_facts f
join dim_company c on c.company_key = f.company_key
join dim_account a on a.account_key = f.account_key
join dim_filing  d on d.filing_key  = f.filing_key
where c.company_name = 'CHEESECAKE FACTORY INC'
  and a.tag_name in ('NetIncomeLoss', 'ProfitLoss')
  and f.period_end_key = date '2025-03-31'
  and f.period_length_qtrs = 1
order by f.is_consolidated desc, f.is_latest_report desc, taken_for nulls last,
         a.tag_name, a.tag_version desc, d.fiscal_period desc;
