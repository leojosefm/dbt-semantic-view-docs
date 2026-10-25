select
    product_id,
    product_name,
    coalesce(product_category, 'Uncategorised') as product_category,
    coalesce(product_brand, 'Unbranded')        as product_brand,
    list_price,
    is_active
from {{ ref('stg_products') }}
