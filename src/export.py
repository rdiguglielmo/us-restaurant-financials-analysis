"""Write the ranking the Power BI page reads to output/. The one script that writes.

    .venv/Scripts/python src/export.py

query.py holds the database in memory and never writes. This script runs the
same chain, 01 to 05, on one connection, so every check in those files prints
again before anything is written. Then it copies one view to Parquet and reads
the written file back. The page computes nothing: every figure on it is a figure
the SQL already printed, so there is one implementation of the ranking, not two.

Three choices a reader might question:

- output/, not data/. query.py registers every Parquet in data/parquet/ and
  every CSV in data/ as an input view. A ranking file there would be read back
  as an input, named like the view 05 creates.
- Parquet, not CSV. The file carries its types. A CSV is typed again by Power
  Query under the machine's locale, where "10.8" can be read as 108 without an
  error.
- ORDER BY before writing. Without it a multi-threaded engine may write the
  rows in a different order on each run, and a binary file in git would change
  with no change in the data.
"""

import hashlib
from pathlib import Path

from query import connect, run_file, show

ROOT = Path(__file__).resolve().parents[1]
CHAIN = [
    "01_concept_resolution.sql",
    "02_financial_statements.sql",
    "03_ratios.sql",
    "04_earnings_quality.sql",
    "05_peer_ranking.sql",
]
RANKING = ROOT / "output" / "peer_ranking.parquet"

# The view as 05 creates it, plus the short name the page displays.
RANKING_QUERY = """
    select n.short_name, p.*
    from peer_ranking p
    join company_names n using (cik)
"""


def main():
    con = connect()
    for name in CHAIN:
        run_file(con, ROOT / "sql" / name)

    RANKING.parent.mkdir(exist_ok=True)
    con.execute(
        f"copy ({RANKING_QUERY} order by p.position, n.short_name) "
        f"to '{RANKING.as_posix()}' (format parquet, compression snappy)"
    )
    written = f"read_parquet('{RANKING.as_posix()}')"

    # Every check below reads the written file, never the query that wrote it.
    show(
        con,
        "X1: the written file against the view",
        [
            "Expected: 10 rows and 25 columns, the view's 24 and the short name,",
            "with 0 columns whose name or type differs from the view's. An inner",
            "join to company_names that missed a cik would show here as 9 rows.",
        ],
        f"""
        select
            (select count(*) from {written})                    as rows_in_file,
            count(f.column_name)                                as columns_in_file,
            count(v.column_name)                                as columns_in_view,
            count(*) filter (where f.column_type is distinct from v.column_type)
                                                                as columns_differing
        from (describe select * from {written}) f
        full join (describe {RANKING_QUERY}) v using (column_name)
        """,
    )

    show(
        con,
        "X2: the ranking and its sensitivity, in the order the file stores them",
        [
            "Expected, identical to K2 and K3. Position, rank sum, then the",
            "position without margin / margin change / growth / leverage:",
            "1 Yum China 15, 1/4/1/3; 2 Chipotle 17, 3/3/3/3;",
            "2 McDonald's 17, 6/6/2/1; 2 Texas Roadhouse 17, 2/2/5/6;",
            "5 Restaurant Brands International 18, 5/1/7/3;",
            "6 Cheesecake Factory 21, 4/7/6/7; 7 Yum Brands 22, 7/5/8/2;",
            "8 Wendy's 24, 7/8/4/8; 9 Bloomin' Brands 33, 9/9/9/10;",
            "10 Papa John's 34, 10/9/10/9.",
            "No ORDER BY here: this is the file's own row order.",
        ],
        f"""
        select
            position,
            short_name,
            rank_sum,
            position_without_margin,
            position_without_margin_change,
            position_without_growth,
            position_without_leverage
        from {written}
        """,
    )

    show(
        con,
        "X3: the earnings quality line on the page",
        [
            "Expected: operating cash flow ahead of consolidated profit, a",
            "negative accruals ratio, for 10 of 10 at 2025-09-30. K5 counts 40",
            "of 40 across the four trailing dates.",
        ],
        f"""
        select
            count(*) filter (where accruals_ratio_pct < 0)      as cash_ahead_of_profit,
            count(*)                                            as companies
        from {written}
        """,
    )

    # Printed so that two runs can be compared: the same data must give the
    # same bytes, or the file's history in git changes without the data.
    digest = hashlib.sha256(RANKING.read_bytes()).hexdigest()
    print(f"\n  wrote {RANKING.relative_to(ROOT).as_posix()}")
    print(f"  {RANKING.stat().st_size:,} bytes, sha256 {digest}\n")


if __name__ == "__main__":
    main()
