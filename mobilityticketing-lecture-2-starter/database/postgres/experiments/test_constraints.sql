-- Lecture 2: Integrity Constraint Tests
-- Negative tests and evidence of successful enforcement (10 constraints)

-- ============================================================================
-- TEST 1: Capacity cannot be negative
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert trip with negative capacity
-- Expected: CONSTRAINT VIOLATION (check constraint fails)
-- SQLSTATE: 23514 (check_violation)
BEGIN;
INSERT INTO trips (id, route_id, service_date, scheduled_departure_utc, status, capacity, reserved_seats)
VALUES ('TRIP-NEG-CAP', 'LINE-M2', '2026-05-01', '2026-05-01 08:00:00+00', 'Scheduled', -1, 0);
-- Expected error: new row for relation "trips" violates check constraint "trips_capacity_non_negative"
ROLLBACK;

-- SUCCESSFUL TEST: Insert trip with zero capacity
BEGIN;
INSERT INTO trips (id, route_id, service_date, scheduled_departure_utc, status, capacity, reserved_seats)
VALUES ('TRIP-ZERO-CAP', 'LINE-M2', '2026-05-01', '2026-05-01 08:00:00+00', 'Scheduled', 0, 0);
COMMIT;
-- Evidence: Success
SELECT * FROM trips WHERE id = 'TRIP-ZERO-CAP';

-- ============================================================================
-- TEST 2: Reserved seats cannot be negative
-- ============================================================================

-- NEGATIVE TEST: Attempt to update trip with negative reserved seats
-- Expected: CONSTRAINT VIOLATION
BEGIN;
UPDATE trips SET reserved_seats = -1 WHERE id = 'TRIP-M2-20260429-0800';
-- Expected error: check constraint violation
ROLLBACK;

-- SUCCESSFUL TEST: Update with valid reserved seats count
BEGIN;
UPDATE trips SET reserved_seats = 5 WHERE id = 'TRIP-M2-20260429-0800';
COMMIT;
-- Evidence: Success
SELECT id, reserved_seats FROM trips WHERE id = 'TRIP-M2-20260429-0800';

-- ============================================================================
-- TEST 3: Reserved seats cannot exceed capacity
-- ============================================================================

-- NEGATIVE TEST: Attempt to set reserved seats greater than capacity
BEGIN;
UPDATE trips SET reserved_seats = 121 WHERE id = 'TRIP-M2-20260429-0800' AND capacity = 120;
-- Expected error: check constraint "trips_reserved_seats_not_exceed_capacity" is violated
ROLLBACK;

-- SUCCESSFUL TEST: Set reserved seats equal to capacity
BEGIN;
UPDATE trips SET reserved_seats = 120 WHERE id = 'TRIP-M2-20260429-0800' AND capacity = 120;
COMMIT;
-- Evidence: Success
SELECT id, capacity, reserved_seats FROM trips WHERE id = 'TRIP-M2-20260429-0800';

-- ============================================================================
-- TEST 4: Product price cannot be negative
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert product with negative price
BEGIN;
INSERT INTO products (code, name, price, currency)
VALUES ('NEGATIVE', 'Invalid product', -10.00, 'DKK');
-- Expected error: check constraint "products_price_non_negative" is violated
ROLLBACK;

-- SUCCESSFUL TEST: Insert product with zero price
BEGIN;
INSERT INTO products (code, name, price, currency)
VALUES ('FREE-PRODUCT', 'Complimentary', 0.00, 'DKK');
COMMIT;
-- Evidence: Success
SELECT code, price FROM products WHERE code = 'FREE-PRODUCT';

-- ============================================================================
-- TEST 5: Product currency must be present
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert product with NULL currency
BEGIN;
INSERT INTO products (code, name, price, currency)
VALUES ('NO-CURRENCY', 'Missing currency', 50.00, NULL);
-- Expected error: check constraint "products_currency_not_null" is violated
ROLLBACK;

-- SUCCESSFUL TEST: Insert product with valid currency
BEGIN;
INSERT INTO products (code, name, price, currency)
VALUES ('VALID-CURRENCY', 'Valid product', 50.00, 'EUR');
COMMIT;
-- Evidence: Success
SELECT code, currency FROM products WHERE code = 'VALID-CURRENCY';

-- ============================================================================
-- TEST 6: Ticket price cannot be negative
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert ticket with negative price
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-NEG-PRICE', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-NEG', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', -50.00, 'DKK'
);
-- Expected error: check constraint "tickets_price_non_negative" is violated
ROLLBACK;

-- SUCCESSFUL TEST: Insert ticket with zero price
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-ZERO-PRICE', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-ZERO', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 0.00, 'DKK'
);
COMMIT;
-- Evidence: Success
SELECT id, price FROM tickets WHERE id = 'TICKET-ZERO-PRICE';

-- ============================================================================
-- TEST 7: Ticket currency must be present
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert ticket with NULL currency
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-NO-CURR', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-NO-CURR', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, NULL
);
-- Expected error: check constraint "tickets_currency_not_null" is violated
ROLLBACK;

-- SUCCESSFUL TEST: Insert ticket with valid currency
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-VALID-CURR', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-VALID-CURR', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK'
);
COMMIT;
-- Evidence: Success
SELECT id, currency FROM tickets WHERE id = 'TICKET-VALID-CURR';

-- ============================================================================
-- TEST 8: Ticket validity end cannot be earlier than start
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert ticket with valid_to_utc before valid_from_utc
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-INVALID-PERIOD', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-INVALID-PERIOD', 'Active', 'SINGLE',
    '2026-04-29 10:00:00+00', '2026-04-29 07:45:00+00', 36.00, 'DKK'
);
-- Expected error: check constraint "tickets_valid_period_valid" is violated
ROLLBACK;

-- SUCCESSFUL TEST: Insert ticket with valid_to_utc equal to valid_from_utc
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-SAME-TIME', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-SAME-TIME', 'Active', 'SINGLE',
    '2026-04-29 08:00:00+00', '2026-04-29 08:00:00+00', 36.00, 'DKK'
);
COMMIT;
-- Evidence: Success
SELECT id, valid_from_utc, valid_to_utc FROM tickets WHERE id = 'TICKET-SAME-TIME';

-- ============================================================================
-- TEST 9: Ticket must refer to an existing user (FK constraint)
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert ticket for non-existent user
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-INVALID-USER', 'USER-NONEXISTENT', 'TRIP-M2-20260429-0800', 'CODE-INVALID-USER', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK'
);
-- Expected error: violates foreign key constraint "tickets_user_id_fk"
ROLLBACK;

-- SUCCESSFUL TEST: Insert ticket for existing user
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-VALID-USER', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-VALID-USER', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK'
);
COMMIT;
-- Evidence: Success
SELECT id, user_id FROM tickets WHERE id = 'TICKET-VALID-USER';

-- ============================================================================
-- TEST 10: Ticket must refer to an existing trip (FK constraint)
-- ============================================================================

-- NEGATIVE TEST: Attempt to insert ticket for non-existent trip
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-INVALID-TRIP', 'USER-1', 'TRIP-NONEXISTENT', 'CODE-INVALID-TRIP', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK'
);
-- Expected error: violates foreign key constraint "tickets_trip_id_fk"
ROLLBACK;

-- SUCCESSFUL TEST: Insert ticket for existing trip
BEGIN;
INSERT INTO tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) VALUES (
    'TICKET-VALID-TRIP', 'USER-1', 'TRIP-M2-20260429-0800', 'CODE-VALID-TRIP', 'Active', 'SINGLE',
    '2026-04-29 07:45:00+00', '2026-04-29 10:00:00+00', 36.00, 'DKK'
);
COMMIT;
-- Evidence: Success
SELECT id, trip_id FROM tickets WHERE id = 'TICKET-VALID-TRIP';
