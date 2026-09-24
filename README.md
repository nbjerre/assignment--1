# Compulsory Assignment 1 review guide

Group members: Nicolai Bjerregaard Jensen
Submitted commit:3866b76049b16ee5df7711d595717e6db016a1a0
Setup and reset instructions: [Lecture 1](mobilityticketing-lecture-1-starter/README.md), [Lecture 2](mobilityticketing-lecture-2-starter/README.md), [Lecture 3](mobilityticketing-lecture-3-starter/README.md), [Lecture 4](mobilityticketing-lecture-4-starter/README.md)

## Where to find the work

Lecture 1: model, workload map and queries: [dossier and ER diagram](mobilityticketing-lecture-1-starter/docs/dossier.md), [relational schema](mobilityticketing-lecture-1-starter/database/postgres/001_relational_baseline.sql), [seed data](mobilityticketing-lecture-1-starter/database/postgres/002_seed.sql), and [query workloads](mobilityticketing-lecture-1-starter/database/postgres/003_queries.sql.example).
Lecture 2: constraints and tests: [completed integrity migration](mobilityticketing-lecture-2-starter/database/postgres/migrations/012_ticketing_integrity.sql), [constraint tests](mobilityticketing-lecture-2-starter/database/postgres/experiments/test_constraints.sql), [integrity map](mobilityticketing-lecture-2-starter/docs/INTEGRITY_MAP.md), and [evidence summary](mobilityticketing-lecture-2-starter/docs/EVIDENCE_SUMMARY.md).
Lecture 3: reporting experiment and comparison: [base revenue query](mobilityticketing-lecture-3-starter/database/postgres/queries/base_revenue.sql), [reporting cases](mobilityticketing-lecture-3-starter/database/postgres/experiments/reporting_cases.sql), [reporting function](mobilityticketing-lecture-3-starter/database/postgres/migrations/020_reporting_function.sql), [trigger summary](mobilityticketing-lecture-3-starter/database/postgres/migrations/021_daily_revenue_trigger.sql), [materialized view](mobilityticketing-lecture-3-starter/database/postgres/migrations/022_daily_captured_revenue.sql), and [reporting evidence](mobilityticketing-lecture-3-starter/docs/reporting-evidence.md).
Lecture 4: migration stages and verification: [migration stages](mobilityticketing-lecture-4-starter/database/postgres/migrations), [migration experiments and verification](mobilityticketing-lecture-4-starter/database/postgres/experiments/lecture04), and [lecture 4 evidence](mobilityticketing-lecture-4-starter/docs/evidence/lecture04/README.md).

## Two decisions worth discussing

1. **Route-stop identity:** I chose `(route_id, stop_sequence)` as the primary key. The alternative was to use a separate route-stop ID or ban repeated stops. The composite key matches the ordered route workload and still permits loop routes. The model and reasoning are in the [Lecture 1 dossier](mobilityticketing-lecture-1-starter/docs/dossier.md).

2. **Revenue reporting:** I chose the direct SQL query or SQL function as the trusted source for daily revenue. The alternative was to use a materialized view or a trigger-maintained summary table to make reads faster. My tests showed that the direct query and function always reflected new payments, status changes, and deletions, while the summary table could become outdated. The results are documented in the [Lecture 3 evidence](mobilityticketing-lecture-3-starter/docs/reporting-evidence.md).

## One limitation or open question

During the Lecture 4 migration, both the old `product_code` column and the new `product_id` column exist for a while so old application code can continue to work. The database does not check that both values refer to the same product, so a direct SQL write could create a mismatch. The new writer avoids this by deriving the product code from the product ID. After the migration, `product_code` is removed and new writes use only `product_id`. This limitation and the migration evidence are documented in the [Lecture 4 evidence](mobilityticketing-lecture-4-starter/docs/evidence/lecture04/README.md).
