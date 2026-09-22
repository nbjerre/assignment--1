# Lecture 4 Evidence

## Step 1: Baseline

The disposable database was rebuilt with `docker compose down -v` followed by
`docker compose up -d postgres`.

Products:

| Code | Price | Currency |
| --- | ---: | --- |
| DAY | 80.00 | DKK |
| SINGLE | 36.00 | DKK |

Existing tickets:

| ID | Product code | Price | Currency |
| --- | --- | ---: | --- |
| TICKET-1 | SINGLE | 36.00 | DKK |
| TICKET-2 | SINGLE | 36.00 | DKK |
| TICKET-3 | DAY | 65.00 | DKK |

The product-reference check in `baseline.sql` returned zero rows.

## Step 2: Unsafe migration

The attempted SQL is saved in `database/postgres/experiments/lecture04/unsafe_change.sql`:

```sql
begin;
alter table tickets drop column product_code;
alter table tickets add column product_id uuid;
alter table tickets alter column product_id set not null;
rollback;
```

Run against the populated disposable database, PostgreSQL returned:

```text
ERROR:  column "product_id" of relation "tickets" contains null values
```

The transaction was rolled back, and the database was reset before continuing.

This is unsafe because existing tickets have no `product_id` values. Dropping
`product_code` first removes the information needed to map each ticket to its
product, so the links cannot be reconstructed from the tickets table. Making
the new column required immediately also fails while existing rows are null.
Old application code that still selects or inserts `tickets.product_code` would
also fail once that column is removed.

## Step 3: Expand the schema

Ran `database/postgres/migrations/030_expand_product_identity.sql` once after
resetting the database. Every product now has a non-null UUID and a unique
constraint. The original `tickets.product_code` values remain unchanged, while
`tickets.product_id` exists and is nullable; the existing tickets currently
have null `product_id` values by design.

The old reader still returned all three original tickets, and the old writer
successfully inserted `LAB04-OLD-1` using only `product_code`. This confirms
that the old application contract remains usable during the expansion.

## Step 4: Dual-version operation

Added `old_writer.sql`, `new_writer.sql`, `old_reader.sql`, and
`new_reader.sql` under `database/postgres/experiments/lecture04/`.

The old writer inserted `LAB04-OLD-2` using only `product_code`. The new
writer inserted `LAB04-NEW-1` using the `DAY` product ID
(`02f9e74f-4627-4762-bfe9-57bf847b38f1`), derived `product_code` from the
matching product row, and stored the purchase price `65.00 DKK` directly on
the ticket. It accepts no product-code input.

The old reader returned all six tickets. The new reader resolved all six:
legacy tickets through `product_code` and the new ticket through
`product_id`, while preserving each ticket's stored price and currency.

Finally, a direct SQL insert with `product_code = 'SINGLE'` and the `DAY`
product ID succeeded, then was rolled back. The current database therefore
does not reject mismatched code/ID pairs. The new writer prevents this specific
mistake at the application/query level by deriving the code from the ID, but
database enforcement will need a later migration if the invariant is required
at the database boundary.

## Step 5: Backfill existing tickets

Added `database/postgres/migrations/031_backfill_ticket_product.sql`, which
updates only rows whose `product_id` is null and matches the existing
`product_code`. The first run backfilled the existing legacy tickets; the
second run changed zero rows.

After changing the test values, `old_writer.sql` created `LAB04-OLD-3` with
only `product_code`. Running the backfill again assigned it the correct
product ID. `verify.sql` returned zero rows.

The original tickets still exist with the original values:

| ID | Product code | Product ID | Price | Currency |
| --- | --- | --- | ---: | --- |
| TICKET-1 | SINGLE | 79564bf8-4924-4408-a9c9-f847e36d63e0 | 36.00 | DKK |
| TICKET-2 | SINGLE | 79564bf8-4924-4408-a9c9-f847e36d63e0 | 36.00 | DKK |
| TICKET-3 | DAY | 02f9e74f-4627-4762-bfe9-57bf847b38f1 | 65.00 | DKK |

## Step 6: Require product IDs

Added and ran `database/postgres/migrations/032_require_ticket_product.sql`.
Before applying it successfully, `old_writer.sql` created `LAB04-OLD-4` with a
null `product_id`. The migration failed with:

```text
ERROR:  column "product_id" of relation "tickets" contains null values
```

After running the backfill, it changed one row (`UPDATE 1`) and `verify.sql`
returned zero rows. The migration then committed successfully, validating the
foreign key and making `tickets.product_id` NOT NULL.

The legacy writer was tested again with `LAB04-OLD-5` and failed as expected:

```text
ERROR:  null value in column "product_id" of relation "tickets" violates not-null constraint
```

## Step 7: Remove the old reference

The repository search found `product_code` in the baseline, backfill,
verification, legacy reader/writer, seed, and evidence files. These are
historical migration steps or retired compatibility checks, not application
code that should remain live after this rollout. No views or functions in the
database reference `tickets.product_code`.

The live dependency check identified the foreign key constraint
`tickets_product_code_fk`. It must be dropped deliberately before the column;
the column was removed without `CASCADE` after the dependency check. The
plain drop rehearsal succeeded and was rolled back; the explicit cleanup then
dropped the constraint and column in a committed transaction.

The new writer now inserts only `product_id` and derives the product through
the product row. The new reader joins products only through `product_id`.
The new writer and reader were tested successfully after removing the legacy
column. The old reader was then tested and failed with `column "product_code"
does not exist`, as expected. The old reader and writer are retained as
historical compatibility scripts, not as live application code.

## Step 8: EF Core comparison

This repository has no EF Core project, solution, C# source, or migration
metadata, so `dotnet ef migrations script --idempotent` could not be run.
Instead, `efcore_draft.cs` contains an AI-drafted EF Core migration for the
expansion phase.

The draft can work out from the model that `products.id` is a UUID with a
database default, `tickets.product_id` is initially nullable, the product ID
index is unique, and a foreign key should connect tickets to products. If the
model removes `tickets.product_code`, EF can also generate a destructive drop
operation.

The draft cannot infer that existing ticket rows must be mapped by their old
`product_code`, or that the new column must remain nullable until the backfill
is complete. It also cannot know that old readers and writers are still live,
that validation should be deferred during rollout, or that ticket prices are
historical purchase values and must not be replaced by current catalogue
prices. Those decisions required inspecting the existing data and application
contracts, so the hand-written migration order remains authoritative here:
expand, backfill, verify, require, then remove the old column.