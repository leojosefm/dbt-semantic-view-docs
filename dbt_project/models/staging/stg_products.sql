-- One row per product.
-- CHANGE: rename the right-hand column names to match your raw table.
select
    product_id,
    product_name,
    product_category,
    product_brand,
    list_price,
    coalesce(is_active, true)        as is_active
from {{ source('raw_sales', 'products') }}
