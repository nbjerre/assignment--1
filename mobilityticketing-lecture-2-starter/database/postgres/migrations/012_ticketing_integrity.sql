-- ============================================================================
-- TRIPS TABLE CONSTRAINTS
-- ============================================================================

-- Invariant: Capacity cannot be negative
ALTER TABLE trips
ADD CONSTRAINT trips_capacity_non_negative
CHECK (capacity >= 0);

-- Invariant: Reserved seats cannot be negative
ALTER TABLE trips
ADD CONSTRAINT trips_reserved_seats_non_negative
CHECK (reserved_seats >= 0);

-- Invariant: Reserved seats cannot exceed capacity
ALTER TABLE trips
ADD CONSTRAINT trips_reserved_seats_not_exceed_capacity
CHECK (reserved_seats <= capacity);

-- ============================================================================
-- PRODUCTS TABLE CONSTRAINTS
-- ============================================================================

-- Invariant: Ticket price cannot be negative
ALTER TABLE products
ADD CONSTRAINT products_price_non_negative
CHECK (price >= 0);

-- Invariant: Currency must be present
ALTER TABLE products
ADD CONSTRAINT products_currency_not_null
CHECK (currency IS NOT NULL);

-- ============================================================================
-- TICKETS TABLE CONSTRAINTS
-- ============================================================================

-- Invariant: Ticket price cannot be negative
ALTER TABLE tickets
ADD CONSTRAINT tickets_price_non_negative
CHECK (price >= 0);

-- Invariant: Currency must be present
ALTER TABLE tickets
ADD CONSTRAINT tickets_currency_not_null
CHECK (currency IS NOT NULL);

-- Invariant: Ticket validity end cannot be earlier than its start
ALTER TABLE tickets
ADD CONSTRAINT tickets_valid_period_valid
CHECK (valid_to_utc >= valid_from_utc);

-- Invariant: A ticket must refer to an existing user
ALTER TABLE tickets
ADD CONSTRAINT tickets_user_id_fk
FOREIGN KEY (user_id) REFERENCES users(id);

-- Invariant: A ticket must refer to an existing trip
ALTER TABLE tickets
ADD CONSTRAINT tickets_trip_id_fk
FOREIGN KEY (trip_id) REFERENCES trips(id);