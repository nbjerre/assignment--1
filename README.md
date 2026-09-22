# Compulsory Assignment 1 review guide

Submitted commit: _add the final commit hash here before submitting in Moodle_

## Setup and reset

Each lecture has its own PostgreSQL Compose project. Run commands from the relevant lecture directory and stop the other lecture database first because they use the same port. The setup and reset commands are described in the [Lecture 1 README](mobilityticketing-lecture-1-starter/README.md), [Lecture 2 README](mobilityticketing-lecture-2-starter/README.md), [Lecture 3 README](mobilityticketing-lecture-3-starter/README.md), and [Lecture 4 README](mobilityticketing-lecture-4-starter/README.md).

The common reset is `docker compose down -v` followed by `docker compose up -d` in the lecture directory being tested. This recreates the disposable PostgreSQL database and reruns its initialization scripts.

## Where to find the work

- **Lecture 1: model, workload map and queries:** [dossier and ER diagram](mobilityticketing-lecture-1-starter/docs/dossier.md), [relational schema](mobilityticketing-lecture-1-starter/database/postgres/001_relational_baseline.sql), [seed data](mobilityticketing-lecture-1-starter/database/postgres/002_seed.sql), and [query workloads](mobilityticketing-lecture-1-starter/database/postgres/003_queries.sql.example).
- **Lecture 2: constraints and tests:** [completed integrity migration](mobilityticketing-lecture-2-starter/database/postgres/migrations/012_ticketing_integrity.sql), [constraint tests](mobilityticketing-lecture-2-starter/database/postgres/experiments/test_constraints.sql), [integrity map](mobilityticketing-lecture-2-starter/docs/INTEGRITY_MAP.md), and [evidence summary](mobilityticketing-lecture-2-starter/docs/EVIDENCE_SUMMARY.md).
- **Lecture 3: reporting experiment and comparison:** [base revenue query](mobilityticketing-lecture-3-starter/database/postgres/queries/base_revenue.sql), [reporting cases](mobilityticketing-lecture-3-starter/database/postgres/experiments/reporting_cases.sql), the [reporting function](mobilityticketing-lecture-3-starter/database/postgres/migrations/020_reporting_function.sql), [trigger summary](mobilityticketing-lecture-3-starter/database/postgres/migrations/021_daily_revenue_trigger.sql), [materialized view](mobilityticketing-lecture-3-starter/database/postgres/migrations/022_daily_captured_revenue.sql), and [reporting evidence](mobilityticketing-lecture-3-starter/docs/reporting-evidence.md).
- **Lecture 4: migration stages and verification:** [migration stages](mobilityticketing-lecture-4-starter/database/postgres/migrations), [migration experiments and verification](mobilityticketing-lecture-4-starter/database/postgres/experiments/lecture04), and [lecture 4 evidence](mobilityticketing-lecture-4-starter/docs/evidence/lecture04/README.md).

## Two decisions worth discussing

1. **Route-stop identity:** We chose `(route_id, stop_sequence)` as the primary key. The alternative was to use a separate route-stop ID or prohibit repeated stops. The composite key matches the ordered route workload and still permits loop routes. The model and reasoning are in the [Lecture 1 dossier](mobilityticketing-lecture-1-starter/docs/dossier.md).

2. **Authoritative revenue reporting:** We recommend the direct aggregate query or SQL function rather than the current trigger-maintained summary as the authoritative result. The alternative is a materialized or trigger-maintained summary for faster reads. The experiment showed that the live query and function reflect status changes and deletes, while the summary can become stale. See the [Lecture 3 evidence](mobilityticketing-lecture-3-starter/docs/reporting-evidence.md).

## One limitation or open question

The Lecture 4 rollout verifies the expand, backfill, require, and remove sequence, but the final database still does not independently reject every mismatched `product_code` and `product_id` pair during the compatibility phase. The new writer derives the code from the product ID, but stronger database enforcement would require another migration. This is documented in the [Lecture 4 evidence](mobilityticketing-lecture-4-starter/docs/evidence/lecture04/README.md). The next check would be to decide whether the legacy compatibility column is still needed and then add and test the required invariant at the database boundary.
