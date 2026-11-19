"""Contract tests for lib/features/ledger/data/schema.sql.

Offline only: plain ``sqlite3`` on ``:memory:``, no Flutter, no network and no
fixtures on disk. Each test builds a fresh database from the schema file and
turns on ``PRAGMA foreign_keys`` like the real adapter must.

The table and column names asserted here are the Captain's adapter contract, so
the tests fail loudly if the shipped DDL drifts from docs/spec/data-model.md.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

SCHEMA_PATH = (
    Path(__file__).resolve().parent.parent
    / "lib"
    / "features"
    / "ledger"
    / "data"
    / "schema.sql"
)

KHATA_COLUMNS = [
    ("id", "TEXT", 1, None, 1),  # primary key
    ("name", "TEXT", 1, None, 0),
    ("opening_balance_paise", "INTEGER", 1, "0", 0),
    ("currency", "TEXT", 1, "'INR'", 0),
    ("sort_order", "INTEGER", 1, "0", 0),
    ("created_at", "TEXT", 1, None, 0),
    ("updated_at", "TEXT", 1, None, 0),
    ("deleted_at", "TEXT", 0, None, 0),
    ("sync_state", "TEXT", 1, "'pending'", 0),
]

TRANSACTION_COLUMNS = [
    ("id", "TEXT", 1, None, 1),
    ("khata_id", "TEXT", 1, None, 0),
    ("type", "TEXT", 1, None, 0),
    ("amount_paise", "INTEGER", 1, None, 0),
    ("category_id", "TEXT", 1, None, 0),
    ("description", "TEXT", 0, None, 0),
    ("occurred_at", "TEXT", 1, None, 0),
    ("note_session_id", "TEXT", 0, None, 0),
    ("created_at", "TEXT", 1, None, 0),
    ("updated_at", "TEXT", 1, None, 0),
    ("deleted_at", "TEXT", 0, None, 0),
    ("sync_state", "TEXT", 1, "'pending'", 0),
]

KHATA_ID = "khata-a"
OTHER_KHATA_ID = "khata-b"
T0 = "2026-11-19T09:00:00.000Z"


def new_db() -> sqlite3.Connection:
    """A fresh in-memory database built from the shipped schema file."""
    connection = sqlite3.connect(":memory:")
    connection.execute("PRAGMA foreign_keys = ON")
    connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
    return connection


def insert_khata(
    connection: sqlite3.Connection,
    khata_id: str = KHATA_ID,
    name: str = "Personal Khata",
    opening_balance_paise: int = 1000000,
) -> None:
    connection.execute(
        "INSERT INTO khatas (id, name, opening_balance_paise, created_at, "
        "updated_at) VALUES (?, ?, ?, ?, ?)",
        (khata_id, name, opening_balance_paise, T0, T0),
    )


def insert_transaction(
    connection: sqlite3.Connection,
    transaction_id: str,
    *,
    khata_id: str = KHATA_ID,
    kind: str = "expense",
    amount_paise: int = 100,
    category_id: str = "Food",
    description: str | None = None,
    occurred_at: str = T0,
    deleted_at: str | None = None,
) -> None:
    """Insert with bound parameters only - never string interpolation."""
    connection.execute(
        "INSERT INTO \"transactions\" (id, khata_id, type, amount_paise, "
        "category_id, description, occurred_at, created_at, updated_at, "
        "deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            transaction_id,
            khata_id,
            kind,
            amount_paise,
            category_id,
            description,
            occurred_at,
            T0,
            T0,
            deleted_at,
        ),
    )


def totals(connection: sqlite3.Connection, khata_id: str) -> tuple[int, int]:
    """The docs/spec formula, as SQL: (total income paise, total expense paise).

    Opening balance is folded into income; tombstones are excluded.
    """
    row = connection.execute(
        "SELECT "
        "  (SELECT opening_balance_paise FROM khatas WHERE id = ?) + "
        "  COALESCE(SUM(CASE WHEN type = 'income' THEN amount_paise END), 0),"
        "  COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_paise END), 0) "
        "FROM \"transactions\" "
        "WHERE khata_id = ? AND deleted_at IS NULL",
        (khata_id, khata_id),
    ).fetchone()
    return int(row[0] or 0), int(row[1] or 0)


# --------------------------------------------------------------------------
# The schema file itself
# --------------------------------------------------------------------------


def test_schema_file_exists_and_is_not_empty():
    assert SCHEMA_PATH.is_file()
    assert SCHEMA_PATH.read_text(encoding="utf-8").strip()


def test_schema_executes_on_a_brand_new_database():
    connection = new_db()
    try:
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name NOT LIKE 'sqlite_%'"
            )
        }
        assert tables == {"khatas", "transactions"}
    finally:
        connection.close()


def test_schema_is_re_runnable_on_a_clean_connection():
    # A second connection must be able to build the same local database, which
    # is what a reinstall/recovery does.
    for _ in range(2):
        connection = new_db()
        try:
            assert connection.execute(
                "SELECT count(*) FROM sqlite_master WHERE type = 'table'"
            ).fetchone()[0] == 2
        finally:
            connection.close()


def schema_statements() -> list[str]:
    """The DDL statements, with full-line comments removed first."""
    sql_lines = [
        line
        for line in SCHEMA_PATH.read_text(encoding="utf-8").splitlines()
        if not line.strip().startswith("--")
    ]
    return [
        token.strip()
        for token in "\n".join(sql_lines).split(";")
        if token.strip()
    ]


def test_schema_contains_only_non_destructive_ddl():
    statements = [statement.upper() for statement in schema_statements()]
    assert len(statements) == 4, statements  # 2 tables + 2 indexes
    for statement in statements:
        assert statement.startswith("CREATE TABLE ") or statement.startswith(
            "CREATE INDEX "
        ), statement
        # No destructive or data-touching statements anywhere.
        for forbidden in (
            "DROP ",
            "DELETE ",
            "TRUNCATE ",
            "ALTER ",
            "INSERT ",
            "UPDATE ",
            "REPLACE ",
            "ATTACH ",
        ):
            assert forbidden not in statement, (forbidden, statement)
    assert "IF NOT EXISTS" not in SCHEMA_PATH.read_text(encoding="utf-8")
    assert len(schema_statements()) == 4


def test_schema_ships_no_rows():
    connection = new_db()
    try:
        assert connection.execute("SELECT count(*) FROM khatas").fetchone()[0] == 0
        assert (
            connection.execute("SELECT count(*) FROM \"transactions\"").fetchone()[0]
            == 0
        )
    finally:
        connection.close()


# --------------------------------------------------------------------------
# Table shapes: names, types, nullability, defaults
# --------------------------------------------------------------------------


def test_khatas_columns_match_the_contract():
    connection = new_db()
    try:
        columns = [
            (row[1], row[2].upper(), row[3], row[4], row[5])
            for row in connection.execute("PRAGMA table_info(khatas)")
        ]
        assert columns == KHATA_COLUMNS
    finally:
        connection.close()


def test_transactions_columns_match_the_contract():
    connection = new_db()
    try:
        columns = [
            (row[1], row[2].upper(), row[3], row[4], row[5])
            for row in connection.execute('PRAGMA table_info("transactions")')
        ]
        assert columns == TRANSACTION_COLUMNS
    finally:
        connection.close()


def test_khata_columns_assert_integer_paise():
    connection = new_db()
    try:
        sql = connection.execute(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'khatas'"
        ).fetchone()[0].lower()
        assert "typeof(opening_balance_paise) = 'integer'" in sql
    finally:
        connection.close()


def test_transaction_columns_assert_integer_paise():
    connection = new_db()
    try:
        sql = connection.execute(
            "SELECT sql FROM sqlite_master WHERE type = 'table' "
            "AND name = 'transactions'"
        ).fetchone()[0].lower()
        assert "typeof(amount_paise) = 'integer'" in sql
        # The positivity rule must survive alongside the type check.
        assert "amount_paise > 0" in sql
    finally:
        connection.close()


@pytest.mark.parametrize(
    "opening_balance_paise",
    [0, 1, 1000000, 10**15, -1, -400, -10**15, 1000.0],
)
def test_integer_opening_balances_are_accepted(opening_balance_paise: int):
    # Zero and negative opening balances are legal: the column has no
    # positivity rule, only the integer-type rule.
    connection = new_db()
    try:
        insert_khata(
            connection, opening_balance_paise=opening_balance_paise
        )
        stored = connection.execute(
            "SELECT opening_balance_paise, typeof(opening_balance_paise) "
            "FROM khatas WHERE id = ?",
            (KHATA_ID,),
        ).fetchone()
        assert stored == (opening_balance_paise, "integer")
    finally:
        connection.close()


@pytest.mark.parametrize(
    "opening_balance_paise",
    [1.5, -0.5, 1000.75],
    ids=["1.5", "-0.5", "1000.75"],
)
def test_fractional_opening_balances_are_rejected(opening_balance_paise: float):
    connection = new_db()
    try:
        with pytest.raises(sqlite3.IntegrityError):
            insert_khata(
                connection, opening_balance_paise=opening_balance_paise
            )
        assert connection.execute("SELECT count(*) FROM khatas").fetchone()[0] == 0
    finally:
        connection.close()


@pytest.mark.parametrize("opening_balance_paise", ["abc", "", "0.5", "~"])
def test_non_numeric_opening_balances_are_rejected(opening_balance_paise: str):
    connection = new_db()
    try:
        with pytest.raises(sqlite3.IntegrityError):
            insert_khata(
                connection, opening_balance_paise=opening_balance_paise
            )
    finally:
        connection.close()


def test_default_opening_balance_is_still_zero():
    connection = new_db()
    try:
        connection.execute(
            "INSERT INTO khatas (id, name, created_at, updated_at) "
            "VALUES (?, ?, ?, ?)",
            (KHATA_ID, "Personal Khata", T0, T0),
        )
        stored = connection.execute(
            "SELECT opening_balance_paise, typeof(opening_balance_paise) "
            "FROM khatas WHERE id = ?",
            (KHATA_ID,),
        ).fetchone()
        assert stored == (0, "integer")
    finally:
        connection.close()


def test_declared_primary_keys():
    connection = new_db()
    try:
        for table in ("khatas", "transactions"):
            primary_keys = [
                row[1]
                for row in connection.execute(f'PRAGMA table_info("{table}")')
                if row[5]
            ]
            assert primary_keys == ["id"], table
    finally:
        connection.close()


def test_transactions_has_no_extra_columns():
    # A Drift adapter generated from the contract must not silently gain or
    # lose a column.
    connection = new_db()
    try:
        names = [
            row[1]
            for row in connection.execute('PRAGMA table_info("transactions")')
        ]
        assert names == [column[0] for column in TRANSACTION_COLUMNS]
    finally:
        connection.close()


# --------------------------------------------------------------------------
# Required indexes
# --------------------------------------------------------------------------


def test_required_indexes_exist_on_the_expected_columns():
    connection = new_db()
    try:
        indexes: dict[str, list[tuple[int, str]]] = {}
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'transactions' AND name NOT LIKE 'sqlite_%'"
        ):
            name = row[0]
            indexes[name] = [
                (info[0], info[2])
                for info in connection.execute(f'PRAGMA index_info("{name}")')
            ]

        assert set(indexes) == {
            "idx_transactions_khata_occurred_at",
            "idx_transactions_sync_state",
        }
        assert indexes["idx_transactions_khata_occurred_at"] == [
            (0, "khata_id"),
            (1, "occurred_at"),
        ]
        assert indexes["idx_transactions_sync_state"] == [(0, "sync_state")]
    finally:
        connection.close()


def test_khata_occurred_at_index_sorts_occurred_at_descending():
    connection = new_db()
    try:
        sql = connection.execute(
            "SELECT sql FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_transactions_khata_occurred_at'"
        ).fetchone()[0]
        assert "DESC" in sql.upper()
        assert "khata_id" in sql
        assert "occurred_at" in sql
    finally:
        connection.close()


# --------------------------------------------------------------------------
# Constraints
# --------------------------------------------------------------------------


def test_foreign_key_points_at_khatas():
    connection = new_db()
    try:
        foreign_keys = list(
            connection.execute('PRAGMA foreign_key_list("transactions")')
        )
        assert len(foreign_keys) == 1
        # (id, seq, table, from, to, on_update, on_delete, match)
        assert foreign_keys[0][2] == "khatas"
        assert foreign_keys[0][3] == "khata_id"
        assert foreign_keys[0][4] == "id"
    finally:
        connection.close()


def test_transaction_for_an_unknown_khata_is_rejected():
    connection = new_db()
    try:
        with pytest.raises(sqlite3.IntegrityError):
            insert_transaction(connection, "txn-orphan", khata_id="khata-missing")
    finally:
        connection.close()


def test_deleting_a_referenced_khata_is_rejected():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "txn-1")
        with pytest.raises(sqlite3.IntegrityError):
            connection.execute("DELETE FROM khatas WHERE id = ?", (KHATA_ID,))
    finally:
        connection.close()


def test_only_income_and_expense_types_are_allowed():
    connection = new_db()
    try:
        insert_khata(connection)
        for kind in ("income", "expense"):
            insert_transaction(connection, f"txn-{kind}", kind=kind)
            connection.commit()

        for bad in ("Income", "EXPENSE", "transfer", "", " expense"):
            with pytest.raises(sqlite3.IntegrityError):
                insert_transaction(
                    connection, f"txn-bad-{bad!r}", kind=bad, amount_paise=1
                )
    finally:
        connection.close()


@pytest.mark.parametrize("amount_paise", [0, -1, -58000])
def test_amount_must_be_strictly_positive(amount_paise: int):
    connection = new_db()
    try:
        insert_khata(connection)
        with pytest.raises(sqlite3.IntegrityError):
            insert_transaction(connection, "txn-1", amount_paise=amount_paise)
    finally:
        connection.close()


@pytest.mark.parametrize(
    "amount_paise",
    [1.5, 0.5, 100.25, -0.5, 999999.999],
    ids=["1.5", "0.5", "100.25", "-0.5", "999999.999"],
)
def test_fractional_amounts_are_rejected(amount_paise: float):
    # INTEGER affinity keeps a fractional REAL as REAL, so `amount_paise > 0`
    # alone would accept 1.5 paise. typeof() closes that hole.
    connection = new_db()
    try:
        insert_khata(connection)
        with pytest.raises(sqlite3.IntegrityError):
            insert_transaction(connection, "txn-fraction", amount_paise=amount_paise)
        assert (
            connection.execute(
                'SELECT count(*) FROM "transactions"'
            ).fetchone()[0]
            == 0
        )
    finally:
        connection.close()


@pytest.mark.parametrize(
    "amount_paise",
    ["abc", "", "1.5", "one hundred", '{"paise": 5}'],
)
def test_non_numeric_amount_text_is_rejected(amount_paise: str):
    connection = new_db()
    try:
        insert_khata(connection)
        with pytest.raises(sqlite3.IntegrityError):
            insert_transaction(connection, "txn-text", amount_paise=amount_paise)
    finally:
        connection.close()


@pytest.mark.parametrize("amount_paise", [2.0, 1e3, "5", "120000"])
def test_integral_reals_and_numeric_text_normalize_to_integer(amount_paise):
    # 2.0, '5' and '120000' have INTEGER affinity and are stored as integers,
    # so they stay legal: the constraint rejects fractions, not coercion.
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "txn-coerced", amount_paise=amount_paise)
        stored, kind = connection.execute(
            'SELECT amount_paise, typeof(amount_paise) FROM "transactions" '
            "WHERE id = ?",
            ("txn-coerced",),
        ).fetchone()
        assert isinstance(stored, int)
        assert kind == "integer"
        assert stored == int(float(amount_paise))
    finally:
        connection.close()


def test_amount_column_typeof_is_always_integer_for_accepted_rows():
    connection = new_db()
    try:
        insert_khata(connection)
        for index, amount in enumerate((1, 100, 120000, 10**15, 2**53 - 1)):
            insert_transaction(connection, f"txn-{index}", amount_paise=amount)
        kinds = {
            row[0]
            for row in connection.execute(
                'SELECT typeof(amount_paise) FROM "transactions"'
            )
        }
        assert kinds == {"integer"}
    finally:
        connection.close()


def test_one_paise_is_accepted():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "txn-1", amount_paise=1)
        stored = connection.execute(
            'SELECT amount_paise FROM "transactions" WHERE id = ?', ("txn-1",)
        ).fetchone()[0]
        assert stored == 1
    finally:
        connection.close()


def test_description_length_limit_is_enforced():
    connection = new_db()
    try:
        insert_khata(connection)
        # 120 characters is legal, 121 is not.
        insert_transaction(connection, "txn-ok", description="a" * 120)
        with pytest.raises(sqlite3.IntegrityError):
            insert_transaction(connection, "txn-too-long", description="a" * 121)
    finally:
        connection.close()


def test_description_stays_optional():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "txn-1", description=None)
        assert (
            connection.execute(
                'SELECT description FROM "transactions" WHERE id = ?', ("txn-1",)
            ).fetchone()[0]
            is None
        )
    finally:
        connection.close()


def test_required_columns_reject_null():
    connection = new_db()
    try:
        insert_khata(connection)
        # khata_id, type, amount_paise, category_id and occurred_at matter most.
        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                'INSERT INTO "transactions" (id, khata_id, type, amount_paise, '
                "category_id, occurred_at, created_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                ("txn-1", KHATA_ID, "expense", 100, "Food", None, T0, T0),
            )
    finally:
        connection.close()


def test_sync_state_and_currency_defaults_are_applied():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "txn-1")

        khata = connection.execute(
            "SELECT currency, sort_order, sync_state, opening_balance_paise "
            "FROM khatas WHERE id = ?",
            (KHATA_ID,),
        ).fetchone()
        assert khata == ("INR", 0, "pending", 1000000)

        transaction = connection.execute(
            'SELECT sync_state, note_session_id, deleted_at FROM "transactions" '
            "WHERE id = ?",
            ("txn-1",),
        ).fetchone()
        assert transaction == ("pending", None, None)
    finally:
        connection.close()


def test_duplicate_primary_keys_are_rejected():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "txn-1")

        with pytest.raises(sqlite3.IntegrityError):
            insert_khata(connection, name="Second Khata")
        with pytest.raises(sqlite3.IntegrityError):
            insert_transaction(connection, "txn-1", amount_paise=999)
    finally:
        connection.close()


def test_client_generated_ids_may_be_any_non_empty_string():
    connection = new_db()
    try:
        insert_khata(connection)
        # UUID v4 style, but the schema deliberately does not constrain format:
        # the id is a client-supplied idempotency key, not a server sequence.
        for index, transaction_id in enumerate(
            (
                "5f0f0f0e-1c2b-4d3e-9a4b-8c7d6e5f4a3b",
                "local-1",
                "txn 2",
                "ട്രാൻസാക്ഷൻ",
            )
        ):
            insert_transaction(connection, transaction_id, amount_paise=index + 1)
        assert (
            connection.execute(
                'SELECT count(*) FROM "transactions"'
            ).fetchone()[0]
            == 4
        )
    finally:
        connection.close()


# --------------------------------------------------------------------------
# Isolation, tombstones and integer paise totals
# --------------------------------------------------------------------------


def test_khatas_are_isolated():
    connection = new_db()
    try:
        insert_khata(connection, KHATA_ID, "Personal Khata", 1000000)
        insert_khata(connection, OTHER_KHATA_ID, "Business Khata", 50000)
        insert_transaction(connection, "a-1", amount_paise=120000)
        insert_transaction(connection, "b-1", khata_id=OTHER_KHATA_ID, amount_paise=700)

        assert totals(connection, KHATA_ID) == (1000000, 120000)
        assert totals(connection, OTHER_KHATA_ID) == (50000, 700)

        ids = [
            row[0]
            for row in connection.execute(
                'SELECT id FROM "transactions" WHERE khata_id = ?', (KHATA_ID,)
            )
        ]
        assert ids == ["a-1"]
    finally:
        connection.close()


def test_tombstoned_rows_are_excluded_from_totals_but_kept():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(connection, "live", amount_paise=4000)
        insert_transaction(
            connection,
            "deleted",
            amount_paise=6000,
            deleted_at="2026-11-20T08:00:00.000Z",
        )

        income, expense = totals(connection, KHATA_ID)
        assert (income, expense) == (1000000, 4000)
        assert income - expense == 996000

        # The tombstone is still on disk: deletes are never physical.
        assert (
            connection.execute(
                'SELECT count(*) FROM "transactions" WHERE deleted_at IS NOT NULL'
            ).fetchone()[0]
            == 1
        )
    finally:
        connection.close()


def test_recent_rows_are_newest_first_and_exclude_tombstones():
    connection = new_db()
    try:
        insert_khata(connection)
        insert_transaction(
            connection, "old", occurred_at="2026-11-17T09:05:00.000Z"
        )
        insert_transaction(
            connection, "newest", occurred_at="2026-11-19T20:30:00.000Z"
        )
        insert_transaction(
            connection, "middle", occurred_at="2026-11-19T13:15:00.000Z"
        )
        insert_transaction(
            connection,
            "removed",
            occurred_at="2026-11-19T23:59:00.000Z",
            deleted_at="2026-11-20T00:01:00.000Z",
        )

        rows = [
            row[0]
            for row in connection.execute(
                'SELECT id FROM "transactions" WHERE khata_id = ? '
                "AND deleted_at IS NULL ORDER BY occurred_at DESC, id ASC "
                "LIMIT 4",
                (KHATA_ID,),
            )
        ]
        assert rows == ["newest", "middle", "old"]
    finally:
        connection.close()


def test_paise_totals_are_exact_integers():
    connection = new_db()
    try:
        insert_khata(connection)
        # 120000 + 58000 + 19900 + 100000 + 30100 + 30000 = 358000 paise, the
        # preview's ₹3,580 with no floating-point drift.
        amounts = (120000, 58000, 19900, 100000, 30100, 30000)
        for index, amount in enumerate(amounts):
            insert_transaction(connection, f"out-{index}", amount_paise=amount)

        income, expense = totals(connection, KHATA_ID)
        assert income == 1000000
        assert expense == 358000
        assert isinstance(expense, int)
        assert income - expense == 642000
    finally:
        connection.close()


def test_large_paise_values_survive_a_round_trip():
    connection = new_db()
    try:
        insert_khata(connection, opening_balance_paise=10**15)
        insert_transaction(connection, "big", amount_paise=10**15)
        insert_transaction(
            connection, "big-income", kind="income", amount_paise=2**53 - 1
        )

        income, expense = totals(connection, KHATA_ID)
        assert income == 10**15 + 2**53 - 1
        assert expense == 10**15
    finally:
        connection.close()


def test_totals_of_an_empty_khata_are_just_the_opening_balance():
    connection = new_db()
    try:
        insert_khata(connection)
        assert totals(connection, KHATA_ID) == (1000000, 0)
    finally:
        connection.close()


def test_foreign_keys_default_off_so_the_caller_must_enable_them():
    # Documents the contract note in schema.sql: the adapter has to run the
    # PRAGMA itself, otherwise the REFERENCES clause above is inert.
    connection = sqlite3.connect(":memory:")
    try:
        connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        assert connection.execute("PRAGMA foreign_keys").fetchone()[0] == 0
        insert_transaction(connection, "txn-orphan")  # accepted while off
    finally:
        connection.close()
