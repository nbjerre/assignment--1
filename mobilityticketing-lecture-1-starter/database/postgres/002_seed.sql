insert into operators (id, name) values
    ('OP-METRO', 'City Metro'),
    ('OP-BUS', 'City Bus')
on conflict do nothing;

insert into routes (id, operator_id, city_id, mode, short_name) values
    ('LINE-M2', 'OP-METRO', 'CPH', 'metro', 'M2'),
    ('LINE-5C', 'OP-BUS', 'CPH', 'bus', '5C')
on conflict do nothing;

insert into stops (id, city_id, name) values
    ('STOP-NORREPORT', 'CPH', 'Nørreport'),
    ('STOP-KONGENS-NYTORV', 'CPH', 'Kongens Nytorv'),
    ('STOP-AIRPORT', 'CPH', 'Copenhagen Airport'),
    ('STOP-CENTRAL', 'CPH', 'Copenhagen Central Station')
on conflict do nothing;

insert into route_stops (route_id, stop_id, stop_sequence) values
    ('LINE-M2', 'STOP-NORREPORT', 1),
    ('LINE-M2', 'STOP-KONGENS-NYTORV', 2),
    ('LINE-M2', 'STOP-AIRPORT', 3),
    ('LINE-5C', 'STOP-CENTRAL', 1),
    ('LINE-5C', 'STOP-NORREPORT', 2),
    ('LINE-5C', 'STOP-AIRPORT', 3)
on conflict do nothing;

insert into trips (id, route_id, service_date, scheduled_departure_utc, status) values
    ('TRIP-M2-20260827-01', 'LINE-M2', date '2026-08-27', timestamptz '2026-08-27 07:30:00+00', 'scheduled'),
    ('TRIP-M2-20260827-02', 'LINE-M2', date '2026-08-27', timestamptz '2026-08-27 08:00:00+00', 'scheduled'),
    ('TRIP-5C-20260827-01', 'LINE-5C', date '2026-08-27', timestamptz '2026-08-27 07:45:00+00', 'scheduled'),
    ('TRIP-5C-20260827-02', 'LINE-5C', date '2026-08-27', timestamptz '2026-08-27 08:15:00+00', 'scheduled')
on conflict do nothing;
