# Integrity Map - Mobility Ticketing

## Summary of Implemented Constraints

| # | Invariant | Affected Tables & Columns | Current Protection | Missing Protection or Limitation | Expected Failure Behaviour | Evidence File |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Capacity cannot be negative | `trips.capacity` | `CHECK (capacity >= 0)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 1 |
| 2 | Reserved seats cannot be negative | `trips.reserved_seats` | `CHECK (reserved_seats >= 0)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 2 |
| 3 | Reserved seats ≤ capacity | `trips.reserved_seats, capacity` | `CHECK (reserved_seats <= capacity)` | Race condition: two concurrent buyers may both observe same remaining capacity; row-level check cannot arbitrate. See Issue 1. | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 3 |
| 4 | Product price ≥ 0 | `products.price` | `CHECK (price >= 0)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 4 |
| 5 | Product currency NOT NULL | `products.currency` | `CHECK (currency IS NOT NULL)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 5 |
| 6 | Ticket price ≥ 0 | `tickets.price` | `CHECK (price >= 0)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 6 |
| 7 | Ticket currency NOT NULL | `tickets.currency` | `CHECK (currency IS NOT NULL)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 7 |
| 8 | Ticket valid_to ≥ valid_from | `tickets.valid_from_utc, valid_to_utc` | `CHECK (valid_to_utc >= valid_from_utc)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 8 |
| 9 | Ticket code unambiguous | `tickets.ticket_code` | `UNIQUE (ticket_code)` | None - complete | UNIQUE_VIOLATION (23505) duplicate_key | test_constraints.sql, TEST 9 |
| 10 | Ticket status in valid set | `tickets.status` | `CHECK (status IN ('Draft', 'Active', 'Validated', 'Expired', 'Cancelled'))` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 10 |
| 11 | Payment → existing ticket (FK) | `payments.ticket_id` | `FOREIGN KEY (ticket_id) REFERENCES tickets(id)` | None - complete | FK_VIOLATION (23503) foreign_key_violation | test_constraints.sql, TEST 11 |
| 12 | Payment amount ≥ 0 | `payments.amount` | `CHECK (amount >= 0)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 12 |
| 13 | Payment currency NOT NULL | `payments.currency` | `CHECK (currency IS NOT NULL)` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 13 |
| 14 | Payment status in valid set | `payments.status` | `CHECK (status IN ('Pending', 'Captured', 'Failed', 'Refunded', 'Disputed'))` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 14 |
| 15 | Validation → existing ticket (FK) | `validations.ticket_id` | `FOREIGN KEY (ticket_id) REFERENCES tickets(id)` | None - complete | FK_VIOLATION (23503) foreign_key_violation | test_constraints.sql, TEST 15 |
| 16 | Validation result in valid set | `validations.result` | `CHECK (result IN ('Accepted', 'Rejected', 'Expired', 'Already-Used', 'Not-Yet-Valid'))` | None - complete | CONSTRAINT_VIOLATION (23514) check_violation | test_constraints.sql, TEST 16 |
| 17 | External payment reference unique (Captured) | `payments.external_payment_reference, status` | `UNIQUE (external_payment_reference, status) WHERE status = 'Captured'` | Partial: prevents duplicate captured references only. Does not prevent accidental resubmission of failed payment attempt. See Issue 2. | UNIQUE_VIOLATION (23505) duplicate_key | test_constraints.sql, TEST 17 |

---

## Issue Register

### Issue 1: Reserved Seats Capacity Race Condition

**Classification:** Dependent on multiple rows + concurrent execution

**Evidence:**
- Two transactions T1 and T2 both read `reserved_seats = 100, capacity = 120`
- Both calculate `available = 20`
- T1 executes `UPDATE trips SET reserved_seats = 110 WHERE id = 'TRIP-X'` (claim 10 seats)
- T2 executes `UPDATE trips SET reserved_seats = 120 WHERE id = 'TRIP-X'` (claim 10 seats)
- Result: 20 seats claimed but only 20 available - no overbooking occurred by luck, but the application logic assumed it was coordinating seat allocation
- Row-level CHECK constraint `reserved_seats <= capacity` only validates end state, not the increment

**Problem:**
- A single CHECK constraint cannot coordinate concurrent requests
- The constraint fires AFTER both increments are applied
- If both transactions start from same baseline and add, the constraint may pass but business logic may be violated

**Consequence:**
- Tickets may be oversold if two concurrent purchase requests both observe remaining capacity and both increment
- No database constraint prevents this - it requires application-level locking or version control

**Specific Improvement:**
- Implement optimistic locking (version column on trips table)
- Or implement pessimistic locking (SELECT ... FOR UPDATE)
- Or track seat reservations in separate tickets table and count live reservations
- See transactions lecture

**Open Question:**
- Should overbooking be prevented strictly, or should system allow overselling with waitlist/standby?
- Is seat allocation first-come-first-served or should there be priority levels?

---

### Issue 2: External Payment Reference Collision

**Classification:** Dependent on external system + business rule ambiguity

**Evidence:**
- Payment gateway returns reference `gateway-capture-0001` for a successful capture
- Application inserts payment with `status = 'Captured'` and `external_payment_reference = 'gateway-capture-0001'`
- If application crashes after receiving gateway callback but before inserting to database:
  - Retry receives same reference again
  - Application attempts to insert payment again
  - UNIQUE constraint (status = 'Captured') prevents duplicate - GOOD
- However, if payment was marked 'Failed' instead of 'Captured':
  - UNIQUE constraint allows same reference again with different status
  - A second payment can be created with same external reference but status = 'Pending'
  - Application logic cannot distinguish which payment actually captured funds

**Problem:**
- The UNIQUE constraint only protects 'Captured' payments
- A payment that failed retry could have same external reference as a later attempt
- Workflow ambiguity: should an external reference appear at most once across ALL statuses, or only once per status?

**Consequence:**
- Potential double-capture if payment gateway is queried before inserting to database
- Reconciliation becomes difficult - which record represents the actual payment?
- Audit trail becomes ambiguous

**Specific Improvement:**
- Option A: Change constraint to `UNIQUE (external_payment_reference)` globally (prevents any duplicate)
  - Trade-off: does not allow re-attempting failed payments with same reference
- Option B: Implement idempotency key separate from external reference
  - Application sends idempotency_key to gateway
  - Gateway returns external_payment_reference from first attempt on retry
  - Database tracks (external_payment_reference, idempotency_key) pair uniquely
- Option C: Implement payment state machine with validation rules in application or function
  - Payments with same external_payment_reference must follow valid state transitions
  - Only 'Captured' or 'Refunded' statuses represent money movement

**Open Question:**
- What is the contract with the payment gateway? Does it guarantee idempotent calls?
- Should the system allow payment retry with new external reference, or reuse same reference?
- Is this a PCI compliance concern (audit trail for payments)?

---

## Additional Invariants - Classification Summary

### Directly Enforceable (Column/Table Constraints)
✓ Capacity cannot be negative — `CHECK`
✓ Reserved seats cannot be negative — `CHECK`
✓ Ticket price cannot be negative — `CHECK`
✓ Payment amount cannot be negative — `CHECK`
✓ Ticket valid_to_utc >= valid_from_utc — `CHECK`
✓ Currency must be present — `CHECK`
✓ Status values from known set (Tickets, Payments, Validations) — `CHECK`
✓ Ticket code unique for lookup — `UNIQUE`

### Enforceable with Unique/Exclusion Rules
✓ External payment reference unique for 'Captured' status — `UNIQUE ... WHERE status = 'Captured'`
⚠ External payment reference handling overall — PARTIAL (see Issue 2)

### Dependent on Multiple Rows
⚠ Reserved seats ≤ capacity (for trip as a whole) — CHECK + concurrent race condition (see Issue 1)
✓ Payment must refer to existing ticket — `FOREIGN KEY`
✓ Validation must refer to existing ticket — `FOREIGN KEY`
✓ Ticket must refer to existing product — `FOREIGN KEY`
✓ Ticket must refer to existing user — `FOREIGN KEY`
✓ Ticket must refer to existing trip — `FOREIGN KEY`
✓ Payment must refer to existing user — `FOREIGN KEY`

### Dependent on External System or Business Rule
❌ Validation ticket_code must match ticket.ticket_code (cross-row, semantic check)
   - Current state: NOT ENFORCED - application must validate
   - Reason: Database has no way to join validation.ticket_code with tickets.ticket_code to verify they match the same ticket
   - Test case: INSERT validation (ticket_id='TICKET-1', ticket_code='CODE-WRONG') could succeed
   - Fix: Application-level validation OR database trigger checking `ticket_code = (SELECT ticket_code FROM tickets WHERE id = ticket_id)`

❌ Disabled user cannot purchase tickets
   - Current state: NOT ENFORCED
   - Reason: Business rule depends on user.is_disabled flag
   - Implementation: Application checks OR database trigger on INSERT tickets
   - Complexity: May need to allow historical tickets for disabled users (audit trail)

❌ Reserved seat increment must not exceed available seats (concurrent coordination)
   - Current state: CHECK constraint prevents FINAL state violation only
   - Race condition: See Issue 1
   - Fix: Application-level locking or optimistic concurrency control

❌ Payment capture idempotency (external gateway coordination)
   - Current state: PARTIAL protection via UNIQUE on external_reference + 'Captured' status
   - Problem: See Issue 2
   - Fix: Application workflow design + trigger validation

---

## Two Critical Invariants for Transactions Lecture

### 1. Concurrent Purchase Race (Reserved Seats Overbooking)

**Rule:** Reserved seats must never exceed trip capacity, even under concurrent purchases.

**Why constraint alone is insufficient:**
- `CHECK (reserved_seats <= capacity)` validates only the final row state
- Two transactions reading the same baseline will not see each other's increments
- Both can apply their increment and pass the check
- Prevents gross violations (reserved > capacity) but not fine-grained overselling

**Recommended transaction-lecture solution:**
- Row-level locks: `SELECT ... FROM trips WHERE id = 'TRIP-X' FOR UPDATE`
- Version/timestamp columns: Application compares baseline version before update
- Separate seating ledger: Track individual reservations, count live ones
- Application enforces: Read current reserved_seats, calculate available, reserve atomically

**Evidence of problem:**
```sql
-- Session 1: T1 reads capacity=120, reserved=100, calculates available=20, plans to book 15
-- Session 2: T2 reads capacity=120, reserved=100, calculates available=20, plans to book 15
-- T1: UPDATE trips SET reserved_seats = 115 WHERE id = 'TRIP-M2-0800'
-- T2: UPDATE trips SET reserved_seats = 115 WHERE id = 'TRIP-M2-0800'  (overwrites T1's update!)
-- Result: 15 seats booked by T2, overwriting T1's booking. 30 seats claimed, 20 available = OVERBOOKING
```

---

### 2. External Payment Capture Idempotency

**Rule:** An external payment reference must be captured exactly once and reconcile with ticket price.

**Why constraint alone is insufficient:**
- External payment gateway is out-of-band from database
- Application may crash after receiving capture confirmation but before inserting payment record
- Retry of same transaction sends same external reference to gateway
- Gateway (well-designed) returns cached result, application must not create duplicate payment
- `UNIQUE (external_payment_reference) WHERE status = 'Captured'` prevents the duplicate in database but:
  - Does NOT prevent application from double-charging customer (gateway may charge both times if retries go to gateway)
  - Does NOT handle race between gateway callback and application crash
  - Does NOT handle payment state machine (what if status changes to 'Refunded'? Can same reference be reused?)

**Recommended transaction-lecture solution:**
- Idempotency key pattern: Store separate idempotency_key generated by application
- Database constraint: `UNIQUE (idempotency_key)` — prevents application from processing same intent twice
- Payment state machine: Define valid transitions (e.g., Pending → Captured → Refunded)
- Trigger on payment UPDATE: Validate state transitions, prevent conflicting updates
- Reconciliation: Periodically query gateway API to verify captured payments match database records
- Saga pattern: If capture fails, trigger refund of any partial captures

**Evidence of problem:**
```sql
-- User initiates payment, application sends to gateway
-- Gateway returns: external_ref='gw-12345', amount=36.00 DKK
-- App inserts: INSERT INTO payments (external_payment_reference='gw-12345', status='Captured', amount=36.00, ...)
-- Database crashes, insert completes but app never gets response
-- App retry: Sends same payment to gateway with idempotency_key='idempotent-999'
-- Gateway: "Already captured this idempotency_key, reference is gw-12345"
-- App sees reference 'gw-12345' already exists in database with status 'Captured'
-- Must recognize this as the same transaction, NOT a new charge
-- If app naively INSERTs again: UNIQUE constraint on (external_reference, status='Captured') prevents it - GOOD
-- But if status was updated to 'Refunded': UNIQUE constraint allows INSERT - BAD (now two captures shown)
```

---

## State-Transition Trace

### Ticket Purchase Flow

**Initial state:** User has account, trip exists with available capacity, product exists.

**Row insertions and updates:**

1. **INSERT tickets row:**
   - `ticket_id='TICKET-NEW'`, `user_id='USER-X'`, `trip_id='TRIP-Y'`, `status='Draft'`
   - All FKs validated
   - No change to trips.reserved_seats

2. **INSERT payments row (Pending):**
   - `payment_id='PAYMENT-NEW'`, `ticket_id='TICKET-NEW'`, `external_payment_reference=NULL`, `status='Pending'`
   - FK to ticket validated
   - No change to trips.reserved_seats yet

3. **External payment capture (gateway call):**
   - Application calls payment gateway
   - Gateway returns `external_payment_reference='gw-12345'` (capture successful)

4. **UPDATE payments row (Pending → Captured):**
   - `UPDATE payments SET status='Captured', external_payment_reference='gw-12345' WHERE id='PAYMENT-NEW'`
   - Constraint validates: `external_payment_reference='gw-12345'` does not exist with status='Captured' (first time)

5. **UPDATE tickets row (Draft → Active):**
   - `UPDATE tickets SET status='Active' WHERE id='TICKET-NEW'`
   - May include incrementing trip.reserved_seats if not done in step 1

6. **UPDATE trips row (increment reserved_seats):**
   - `UPDATE trips SET reserved_seats = reserved_seats + 1 WHERE id='TRIP-Y'`
   - Constraint validates: `reserved_seats <= capacity` still true
   - **CONCURRENCY RISK:** If two transactions both do this step simultaneously (Issue 1)

**References must already exist at each step:**
- tickets INSERT: user_id, trip_id, product_code must exist
- payments INSERT: user_id, ticket_id must exist
- Validations cannot be inserted until ticket exists

---

### Ticket Validation Flow

**Initial state:** Ticket is 'Active', valid time window is current, device/vehicle/stop exist.

**Row insertions:**

1. **INSERT validations row:**
   - `validation_id='VALIDATION-NEW'`, `ticket_id='TICKET-ACTIVE'`, `ticket_code='CODE-ACTIVE'`, `result='Accepted'`
   - FK: ticket_id must exist
   - **SEMANTIC RISK:** No database check that ticket_code matches the ticket_id (Issue: cross-row identity check)

2. **UPDATE tickets row (Active → Validated):**
   - `UPDATE tickets SET status='Validated' WHERE id='TICKET-ACTIVE'`
   - Constraint validates: status is in valid set

**References must already exist:**
- validations INSERT: ticket_id must exist
- Vehicle, stop, device are not foreign keys (intentionally - they come from external GTFS/booking system)

---

## Delete and Update Behaviour

### Tickets Table (Historical records)

**Deletion:** RESTRICT (do not allow)
- Reason: Tickets are audit trail for purchase history. Deleting ticket would lose payment/validation history.
- Risk: Cannot trace overbooking, fraud, or refund disputes if ticket disappears.
- Recommendation: Use soft-delete (add `deleted_at` column, query with `WHERE deleted_at IS NULL`)

**Updates:**
- `user_id`: RESTRICT - cannot change who ticket belongs to (audit trail)
- `trip_id`: RESTRICT - cannot change trip after purchase (audit trail)
- `status`: ALLOW - status transitions are expected (Draft → Active → Validated → Expired)
- `ticket_code`: RESTRICT - code is identifier, changing it breaks validation links
- `valid_from_utc`, `valid_to_utc`: RESTRICT - validity window is contract, cannot change retroactively
- `price`, `currency`: RESTRICT - historical record of what customer paid
- **Validation:** Application layer should enforce status transition rules (Draft → Active → {Validated|Expired|Cancelled})

### Payments Table (Financial records)

**Deletion:** RESTRICT (do not allow)
- Reason: Payments are financial audit trail. PCI compliance may require retention.
- Risk: Deleting payment hides refunds, captures, disputes.
- Recommendation: Soft-delete or retention policy (e.g., keep 7 years)

**Updates:**
- `external_payment_reference`: RESTRICT - once captured, cannot change the gateway reference
- `status`: ALLOW - state transitions: Pending → {Captured|Failed}, Captured → {Refunded|Disputed}
- `amount`, `currency`: RESTRICT - historical record of what was charged
- `ticket_id`: RESTRICT - payment must stay associated with original ticket
- **Validation:** Application layer should validate state transitions and prevent reversions (e.g., Captured → Pending)

### Validations Table (Validation records)

**Deletion:** RESTRICT (or soft-delete)
- Reason: Validations are audit trail for fare enforcement. Deleting hides fraud/fare evasion.
- Risk: Losing evidence that ticket was used.
- Recommendation: Soft-delete or retention policy

**Updates:**
- `ticket_id`, `ticket_code`: RESTRICT - which ticket was validated is immutable
- `result`: RESTRICT - validation result is historical fact (either passed or failed)
- `validated_utc`: RESTRICT - timestamp is immutable
- **Rationale:** Once validation record is created, it is historical evidence. Changes would hide fraud.

### Trips Table (Schedule records)

**Deletion:** Context-dependent
- If trip is future-scheduled: may allow DELETE if no tickets sold yet
- If trip has past service_date or has reservations: RESTRICT
- Recommendation: Soft-delete with `cancelled_at` or status='Cancelled'

**Updates:**
- `scheduled_departure_utc`: RESTRICT - changes to schedule should create new trip record (new trip_id)
- `capacity`: RESTRICT - after sales begin, cannot reduce capacity (would violate check on existing reserved_seats). Cannot arbitrarily increase.
- `reserved_seats`: ALLOW - incremented as new tickets are sold
- `status`: ALLOW - status transitions: Scheduled → {In-Service|Completed|Cancelled}
- **Validation:** Cannot reduce capacity below current reserved_seats count

---

## Coverage of Minimum Invariants

| Invariant | Status | Implementation | Evidence |
| --- | --- | --- | --- |
| Capacity cannot be negative | ✓ Implemented | `CHECK (capacity >= 0)` | TEST 1 |
| Reserved seats cannot be negative or > capacity | ✓ Implemented | `CHECK (reserved_seats >= 0)` and `CHECK (reserved_seats <= capacity)` | TEST 2, TEST 3 |
| Ticket price and payment amount cannot be negative | ✓ Implemented | `CHECK (price >= 0)` on tickets and payments | TEST 6, TEST 12 |
| Currency must be present and consistently represented | ✓ Implemented | `CHECK (currency IS NOT NULL)` on products, tickets, payments | TEST 5, TEST 7, TEST 13 |
| Ticket codes must support unambiguous lookup | ✓ Implemented | `UNIQUE (ticket_code)` | TEST 9 |
| A payment must refer to an existing ticket | ✓ Implemented | `FOREIGN KEY (ticket_id) REFERENCES tickets(id)` | TEST 11 |
| A validation must refer to an existing ticket | ✓ Implemented | `FOREIGN KEY (ticket_id) REFERENCES tickets(id)` | TEST 15 |
| A ticket validity end cannot be earlier than its start | ✓ Implemented | `CHECK (valid_to_utc >= valid_from_utc)` | TEST 8 |
| Status values must come from a known set | ✓ Implemented | `CHECK (status IN (...))` on tickets, payments, validations | TEST 10, TEST 14, TEST 16 |
| External payment reference should not be recorded twice for captured payments | ✓ Implemented (PARTIAL) | `UNIQUE (external_payment_reference, status) WHERE status = 'Captured'` | TEST 17 (see Issue 2 for limitations) |
| Validation must not combine ticket ID of one with code of another | ❌ Not implemented | Requires trigger or application logic | Documented in Issue: cross-row semantic check |

