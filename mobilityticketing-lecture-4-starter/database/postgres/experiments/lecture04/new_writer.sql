\set ticket_id 'LAB04-NEW-2'
\set ticket_code 'LAB04-CODE-NEW-2'
\set product_id '02f9e74f-4627-4762-bfe9-57bf847b38f1'
\set purchase_price '65.00'
\set purchase_currency 'DKK'

insert into tickets
  (id, user_id, trip_id, ticket_code, status, product_id,
     valid_from_utc, valid_to_utc, price, currency)
select :'ticket_id', source.user_id, source.trip_id, :'ticket_code',
  coalesce(source.status, 'Active'), product.id,
       source.valid_from_utc, source.valid_to_utc,
       :'purchase_price', :'purchase_currency'
from tickets source
cross join products product
where source.id = 'TICKET-3'
  and product.id = :'product_id';