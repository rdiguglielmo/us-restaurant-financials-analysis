-- Reconciliation gate. Run this before trusting any figure in this repository:
--
--   .venv/Scripts/python src/query.py sql/00_reconciliation_gate.sql
--
-- This project recalculates ratios over a warehouse another project built and
-- published. It has no quality layer of its own, so this gate is what stands in
-- its place: the figures computed here must reproduce the ones the upstream
-- pipeline already published. If they diverge, one of the two is wrong and
-- neither ships. The expectation is written above each query and is never
-- adjusted to match a result.
--
-- ---------------------------------------------------------------------------
-- Which flags every query below applies, and why
-- ---------------------------------------------------------------------------
-- The fact table carries three flags because three properties of the source
-- produce a total larger than the truth without raising an error. Ignoring a
-- single one of them makes a total 2.21 times too large.
--
--   is_consolidated = true     A consolidated figure and each of its segment
--                              breakdowns share the same tag, period and unit.
--                              11,362 of 22,604 facts are breakdowns.
--
--   is_latest_report = true    Every 10-Q restates the prior-year comparative,
--                              so the same economic fact arrives from several
--                              filings. 1,840 of 22,604 are superseded.
--
--   is_year_to_date = false    Expressed here as period_length_qtrs in (0, 1, 4)
--                              rather than as the flag: year-to-date is true
--                              only for the half-year and nine-month durations,
--                              so those grains exclude it by construction.
--
--   unit_of_measure = 'USD'    Not a hazard flag but equally required: the
--                              scope also reports share counts, and adding a
--                              share to a dollar is arithmetic on incompatible
--                              quantities.
--
-- ---------------------------------------------------------------------------
-- The fifth position, which the four above do not cover
-- ---------------------------------------------------------------------------
-- dim_account is grained on (tag_name, tag_version), not on the concept name.
-- A company that files the same concept under two taxonomy years produces two
-- rows that both survive every flag above, because they are two distinct
-- economic facts by the upstream grain. Joining dim_account on tag_name
-- without a tie-break therefore duplicates: 465 of 6,717 company / concept /
-- periods in this scope, and GATE 7 measures it.
--
-- So every resolution below orders by tag_preference first and then by
-- tag_version descending, taking the most recent taxonomy. In 464 of those 465
-- cases the two versions carry the same value and the rule is a formality. In
-- one they do not, and there the rule is the whole difference between a figure
-- and a coin toss.
--
-- Concepts resolve through data/concept_mapping.csv, registered as the view
-- `concept_mapping`. No query hardcodes a tag list, and every query reports
-- which tag it actually used, so a figure can be audited back to the filing.

-- --- GATE 1: source fingerprint
-- Expected: 22,604 facts, 1,066 accounts, 493 distinct tag names, 10 companies.
-- Any other figure means the Parquet in data/parquet/ are not the files the
-- upstream pipeline published, and nothing below this line can be trusted.
select
    (select count(*)                   from fct_financial_facts) as facts,
    (select count(*)                   from dim_account)         as accounts,
    (select count(distinct tag_name)   from dim_account)         as tag_names,
    (select count(*)                   from dim_company)         as companies;

-- --- GATE 2: net margin, 2025 Q3, discrete quarter
-- Expected, against the figures the upstream project published:
--   McDonald's 32.2%, Papa John's 0.9%, Bloomin' Brands -4.9%.
-- Ten rows. Two companies resolve the bottom line through the ProfitLoss
-- fallback and must still reconcile; net_income_tag reports which did.
with resolved as (
    select
        c.company_name,
        c.cik,
        m.concept,
        m.tag_name,
        m.tag_preference,
        f.value
    from fct_financial_facts f
    join dim_company     c on c.company_key = f.company_key
    join dim_account     a on a.account_key = f.account_key
    join dim_date        d on d.date_key    = f.period_end_key
    join concept_mapping m on m.tag_name    = a.tag_name
    where f.is_consolidated
      and f.is_latest_report
      and f.unit_of_measure = 'USD'
      and f.period_length_qtrs = 1
      and f.value is not null
      and d.calendar_year = 2025
      and d.calendar_quarter = 3
      and m.concept in ('revenue', 'net_income')
    qualify row_number() over (
        partition by c.cik, m.concept, f.period_end_key
        order by m.tag_preference, a.tag_version desc
    ) = 1
)
select
    company_name,
    round(max(value) filter (where concept = 'revenue')    / 1e6, 1) as revenue_musd,
    round(max(value) filter (where concept = 'net_income') / 1e6, 1) as net_income_musd,
    round(100.0 * max(value) filter (where concept = 'net_income')
          / nullif(max(value) filter (where concept = 'revenue'), 0), 1) as net_margin_pct,
    max(tag_name) filter (where concept = 'net_income')                 as net_income_tag
from resolved
group by 1
order by net_margin_pct desc;

-- --- GATE 3: operating margin, FY2024
-- Expected: McDonald's 45.2%, Bloomin' Brands 3.5%, and a spread of 41.7
-- points between them. Ten rows.
-- revenue_tag reports which of the three revenue elements each company
-- resolved to, because no single tag carries revenue for all ten.
with resolved as (
    select
        c.company_name,
        c.cik,
        m.concept,
        m.tag_name,
        m.tag_preference,
        f.value
    from fct_financial_facts f
    join dim_company     c on c.company_key = f.company_key
    join dim_account     a on a.account_key = f.account_key
    join dim_date        d on d.date_key    = f.period_end_key
    join concept_mapping m on m.tag_name    = a.tag_name
    where f.is_consolidated
      and f.is_latest_report
      and f.unit_of_measure = 'USD'
      and f.period_length_qtrs = 4
      and f.value is not null
      and d.calendar_year = 2024
      and m.concept in ('revenue', 'operating_income')
    qualify row_number() over (
        partition by c.cik, m.concept, f.period_end_key
        order by m.tag_preference, a.tag_version desc
    ) = 1
)
select
    company_name,
    round(max(value) filter (where concept = 'revenue')          / 1e9, 2) as revenue_busd,
    round(max(value) filter (where concept = 'operating_income') / 1e9, 2) as operating_income_busd,
    round(100.0 * max(value) filter (where concept = 'operating_income')
          / nullif(max(value) filter (where concept = 'revenue'), 0), 1)   as operating_margin_pct,
    max(tag_name) filter (where concept = 'revenue')                       as revenue_tag
from resolved
group by 1
order by operating_margin_pct desc;

-- --- GATE 4: concept coverage after the mapping is applied
-- Expected, companies reached once the priority order resolves:
--   revenue 10, net_income 10, operating_income 10, operating_cash_flow 10,
--   total_assets, current_assets, current_liabilities, stockholders_equity 10,
--   total_liabilities 9 before derivation, stockholders_equity_incl_nci 7,
--   redeemable_nci 2, and net_income_consolidated 10, the same two elements
--   as net_income in the opposite order.
-- These are the numbers that govern the metric catalogue. The per-tag counts
-- in the mapping file are lower because no single tag carries a concept.
select
    m.concept,
    count(distinct f.company_key)                                             as companies,
    count(distinct case when f.period_length_qtrs = 1 then f.company_key end) as companies_quarterly,
    count(distinct case when f.period_length_qtrs = 4 then f.company_key end) as companies_annual,
    count(distinct case when f.period_length_qtrs = 0 then f.company_key end) as companies_instant
from fct_financial_facts f
join dim_account     a on a.account_key = f.account_key
join concept_mapping m on m.tag_name    = a.tag_name
where f.is_consolidated
  and f.is_latest_report
  and f.unit_of_measure = 'USD'
  and f.period_length_qtrs in (0, 1, 4)
  and f.value is not null
group by 1
order by 1;

-- --- GATE 5: total liabilities against the balance-sheet identity
-- One company never reports Liabilities, so it has to be derived. The identity
-- is not assets minus equity: redeemable noncontrolling interest is mezzanine,
-- carried outside permanent equity and outside liabilities both, so it needs
-- its own term:
--   liabilities = assets - equity_incl_nci - redeemable_nci
-- Expected: zero instants not closing, on all nine companies that report
-- Liabilities directly. An earlier rule omitting the mezzanine term missed by
-- 13 m on Yum China and 0.9 m on Papa John's, which is how the term was found.
with bs as (
    select
        c.company_name,
        f.period_end_key,
        m.concept,
        f.value
    from fct_financial_facts f
    join dim_company     c on c.company_key = f.company_key
    join dim_account     a on a.account_key = f.account_key
    join concept_mapping m on m.tag_name    = a.tag_name
    where f.is_consolidated
      and f.is_latest_report
      and f.unit_of_measure    = 'USD'
      and f.period_length_qtrs = 0
      and f.value is not null
      and m.concept in ('total_assets', 'total_liabilities', 'redeemable_nci',
                        'stockholders_equity', 'stockholders_equity_incl_nci')
    qualify row_number() over (
        partition by c.cik, m.concept, f.period_end_key
        order by m.tag_preference, a.tag_version desc
    ) = 1
),
pivoted as (
    select
        company_name,
        period_end_key,
        max(value) filter (where concept = 'total_assets')      as assets,
        max(value) filter (where concept = 'total_liabilities') as liabilities_reported,
        coalesce(max(value) filter (where concept = 'redeemable_nci'), 0) as redeemable_nci,
        coalesce(max(value) filter (where concept = 'stockholders_equity_incl_nci'),
                 max(value) filter (where concept = 'stockholders_equity')) as equity_total
    from bs
    group by 1, 2
)
select
    company_name,
    count(*)                                                    as instants_compared,
    max(abs(liabilities_reported
            - (assets - equity_total - redeemable_nci)))        as max_abs_difference,
    count(*) filter (
        where abs(liabilities_reported
                  - (assets - equity_total - redeemable_nci)) > 0.5
    )                                                           as instants_not_closing
from pivoted
where liabilities_reported is not null
  and assets is not null
  and equity_total is not null
group by 1
order by max_abs_difference desc, company_name;

-- --- GATE 6: the ROE pairing rule, FY2024
-- The bottom line and the equity denominator carry opposite positions on
-- noncontrolling interests: ProfitLoss includes them, StockholdersEquity
-- excludes them. Pairing across that boundary inflates ROE, and not slightly:
-- Restaurant Brands reports 3,110 m without the minority and 4,843 m with it.
-- The rule: the denominator follows whichever element the numerator resolved
-- to. Expected: ten rows, one per company, pair_is_consistent true on all ten.
-- Equity is taken at the period end. This gate proves the pairing, not the
-- annualisation choice, which belongs to the metric definitions.
with facts as (
    select
        c.company_name,
        c.cik,
        m.concept,
        m.tag_name,
        m.tag_preference,
        a.tag_version,
        f.period_length_qtrs,
        f.period_end_key,
        f.value
    from fct_financial_facts f
    join dim_company     c on c.company_key = f.company_key
    join dim_account     a on a.account_key = f.account_key
    join concept_mapping m on m.tag_name    = a.tag_name
    where f.is_consolidated
      and f.is_latest_report
      and f.unit_of_measure = 'USD'
      and f.value is not null
),
net_income as (
    select company_name, cik, tag_name, value
    from facts
    where concept = 'net_income'
      and period_length_qtrs = 4
      and period_end_key = date '2024-12-31'
    qualify row_number() over (
        partition by cik order by tag_preference, tag_version desc
    ) = 1
),
equity as (
    select cik, concept, value
    from facts
    where concept in ('stockholders_equity', 'stockholders_equity_incl_nci')
      and period_length_qtrs = 0
      and period_end_key = date '2024-12-31'
    qualify row_number() over (
        partition by cik, concept order by tag_version desc
    ) = 1
),
paired as (
    select
        n.company_name,
        n.tag_name as net_income_tag,
        case when n.tag_name = 'ProfitLoss'
             then 'stockholders_equity_incl_nci'
             else 'stockholders_equity'
        end        as equity_concept,
        n.value    as net_income,
        e.value    as equity
    from net_income n
    left join equity e
           on e.cik = n.cik
          and e.concept = case when n.tag_name = 'ProfitLoss'
                               then 'stockholders_equity_incl_nci'
                               else 'stockholders_equity' end
)
select
    company_name,
    net_income_tag,
    equity_concept,
    round(net_income / 1e6, 0)                      as net_income_musd,
    round(equity / 1e6, 0)                          as equity_musd,
    case when equity > 0
         then round(100.0 * net_income / equity, 1)
    end                                             as roe_pct,
    equity is not null                              as pair_is_consistent,
    equity < 0                                      as has_negative_equity
from paired
order by company_name;

-- --- GATE 7: the taxonomy-version duplication, measured
-- A concept filed under two taxonomy years survives every flag twice. This
-- measures the hazard the tie-break exists to defeat, so that a later change
-- to the upstream export cannot quietly widen it.
-- Expected: 6,717 company / concept / periods, 465 of them duplicated (6.9%),
-- worst case 4 rows for one figure, and exactly 1 where the two versions
-- disagree on the value. That one is Cheesecake Factory's current contract
-- liability at 2024-06-30: 192.3 m against 226.8 m, a 17.9% gap that max()
-- would have resolved silently and wrongly.
with grouped as (
    select
        f.company_key,
        a.tag_name,
        f.period_end_key,
        f.period_length_qtrs,
        count(*)                  as rows_for_one_figure,
        count(distinct f.value)   as distinct_values
    from fct_financial_facts f
    join dim_account a on a.account_key = f.account_key
    where f.is_consolidated
      and f.is_latest_report
      and f.unit_of_measure = 'USD'
      and f.period_length_qtrs in (0, 1, 4)
      and f.value is not null
    group by 1, 2, 3, 4
)
select
    count(*)                                                  as company_concept_periods,
    count(*) filter (where rows_for_one_figure > 1)           as duplicated,
    round(100.0 * count(*) filter (where rows_for_one_figure > 1)
          / count(*), 1)                                      as pct_duplicated,
    max(rows_for_one_figure)                                  as worst_case_rows,
    count(*) filter (where distinct_values > 1)               as versions_disagree_on_value
from grouped;
