select t.id,
       p.id as product_id,
       t.price,
       t.currency
from tickets t
join products p
  on p.id = t.product_id
order by t.id;