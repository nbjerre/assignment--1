create table operators (
    id text primary key,
    name text not null
);

create table routes (
    id text primary key,
    operator_id text not null references operators(id),
    city_id text not null,
    mode text not null,
    short_name text not null
);

create table stops (
    id text primary key,
    city_id text not null,
    name text not null
);

create table route_stops (
    route_id text not null references routes(id),
    stop_id text not null references stops(id),
    stop_sequence integer not null,
    -- route id og stop sequence bestemmer sammen en rute og et stoppested.
    --En rute kan ikke have to stoppesteder.
    --Et stoppested kan godt forekomme flere gange på samme rute, med en løkke fx.
    --stop_sequence bestemmer rækkefølgen af stoppestederne.
    --Eksempel: På LINE-M2 er Nørreport nummer 1, Kongens Nytorv nummer 2 og lufthavnen nummer 3.
    primary key (route_id, stop_sequence),
    constraint route_stops_sequence_positive check (stop_sequence > 0)
);

create table trips (
    id text primary key,
    route_id text not null references routes(id),
    service_date date not null,
    scheduled_departure_utc timestamptz not null,
    status text not null
);
