"""Run SQL against the committed Parquet and print the result. Read-only.

    .venv/Scripts/python src/query.py sql/00_reconciliation_gate.sql
    .venv/Scripts/python src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql
    .venv/Scripts/python src/query.py "SELECT * FROM dim_company"

Every Parquet file in data/parquet/ is registered as a view named after the
file, so a query says `dim_company` rather than a path, and every CSV in data/
the same way: `concept_mapping`, `fiscal_calendar`. The database is
held in memory and nothing is ever written: there is no warehouse to build
first, which is what lets this repository run straight after a clone.

Given a .sql file, every section introduced by a `-- --- NAME` marker is run in
turn, with the comment lines under the marker printed above its result. That is
how the gates state their expected answer before showing the actual one. A
section that creates a view is executed and reported by name. Several files
run in order on one connection, so a later file reads an earlier one's views.
Given anything else, the argument is run as a single query.
"""

import re
import sys
from pathlib import Path

import duckdb

# Derived from this file, never from the working directory, so the script runs
# the same from the repository root as from anywhere else.
PARQUET = Path(__file__).resolve().parents[1] / "data" / "parquet"
MARKER = "-- --- "


def connect():
    files = sorted(PARQUET.glob("*.parquet"))
    if not files:
        sys.exit(f"no Parquet files in {PARQUET}")
    con = duckdb.connect()
    for f in files:
        con.sql(
            f"create view {f.stem} as "
            f"select * from read_parquet('{f.as_posix()}')"
        )

    # Reference tables are data, not code: the concept mapping and the fiscal
    # calendar each live in one CSV in data/, registered under the file's name,
    # instead of a VALUES list repeated in every query that needs them. A cik
    # column is forced to text: left to type detection, 0000030697 becomes the
    # integer 30697 and joins nothing, without an error.
    for f in sorted(PARQUET.parent.glob("*.csv")):
        header = f.read_text(encoding="utf-8").splitlines()[0].split(",")
        types = ", types = {'cik': 'VARCHAR'}" if "cik" in header else ""
        con.sql(
            f"create view {f.stem} as select * from "
            f"read_csv('{f.as_posix()}', header = true{types})"
        )
    return con


def show(con, title, notes, statement):
    """Run one statement and print it as a fixed width table.

    The banner and the notes are printed BEFORE the query executes. That
    ordering is the point of this function rather than an accident of layout:
    a gate's expected answer reaches the screen while the actual one does not
    yet exist, so there is no opportunity to reword the expectation to suit
    the result.
    """
    if title:
        print("\n" + "=" * 78)
        print(title)
        print("=" * 78)
    for n in notes:
        print("  " + n)
    if notes:
        print()

    # A section that creates a view defines something later sections and
    # later files read. It returns no rows, so there is nothing to tabulate.
    if statement.lower().startswith("create"):
        con.sql(statement)
        name = re.search(r"view\s+(\w+)", statement, re.IGNORECASE)
        print(f"  created {name.group(1) if name else 'object'}")
        return

    rel = con.sql(statement)
    rows, cols = rel.fetchall(), rel.columns

    # Thousands separators on integers only. Floats and decimals are left as
    # the engine rendered them, because a figure this project reports should
    # be read exactly as it was computed.
    def fmt(v):
        return f"{v:,}" if isinstance(v, int) else str(v)

    # Each column is as wide as its header or its longest formatted value,
    # whichever is greater, so that the rule under the header lines up with
    # the data. With no rows there is nothing to measure but the header.
    widths = [
        max([len(c)] + [len(fmt(r[i])) for r in rows]) if rows else len(c)
        for i, c in enumerate(cols)
    ]

    def line(cells):
        return "  " + "  ".join(c.ljust(w) for c, w in zip(cells, widths))

    print(line(cols))
    print(line(["-" * w for w in widths]))
    for r in rows:
        print(line([fmt(v) for v in r]))
    print(f"\n  ({len(rows)} row{'' if len(rows) == 1 else 's'})")


def run_file(con, path):
    """Run every section of one .sql file, in order, on the given connection."""
    # [1:] drops whatever precedes the first marker. That is the file's
    # prose header, which explains the flags the queries apply: meant for
    # a reader, never for the engine.
    blocks = path.read_text(encoding="utf-8").split(MARKER)[1:]
    if not blocks:
        sys.exit(f"no '{MARKER}' section markers in {path}")
    for block in blocks:
        header, _, body = block.partition("\n")

        # The comment prefix does two different jobs, told apart by
        # indentation. At column zero a comment is the section's stated
        # expectation and is printed above the result, with the leading
        # "-- " sliced off. Indented, it is an aside to whoever reads the
        # file: still removed from the SQL below, but never displayed.
        notes = [ln[3:].strip() for ln in body.splitlines() if ln.startswith("--")]

        # Every comment line goes, at either indentation, and the trailing
        # semicolon with them: con.sql() takes one statement, not a script.
        sql = "\n".join(
            ln for ln in body.splitlines() if not ln.lstrip().startswith("--")
        ).strip().rstrip(";").strip()

        # A section that is all prose and no SQL is documentation between
        # gates, so it is skipped rather than sent to the engine as "".
        if sql:
            show(con, header.replace("-", " ").strip(), [n for n in notes if n], sql)


def main():
    """Dispatch on the arguments: one or more .sql files, or a single query.

    Several files run in the order given, on one connection, so a later file
    reads the views an earlier one created:

        src/query.py sql/01_concept_resolution.sql sql/02_financial_statements.sql

    Every upstream check therefore runs again whenever a downstream file does.
    Anything that is not a .sql file on disk is treated as one query.
    """
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)          # the module docstring is the usage message

    con = connect()
    paths = [Path(a) for a in args]

    if all(p.suffix.lower() == ".sql" and p.exists() for p in paths):
        for p in paths:
            run_file(con, p)
    elif len(args) == 1:
        show(con, None, [], args[0])
    else:
        sys.exit("several arguments must all be .sql files that exist")

    print()


if __name__ == "__main__":
    main()
