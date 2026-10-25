-- One row per sales order line.
-- CHANGE: rename the right-hand column names to match your raw table.
select
    order_line_id,
    order_id,
    customer_id,
    product_id,
    cast(order_date as date)         as order_date,
    upper(order_status)              as order_status,
    quantity,
    unit_price,
    coalesce(discount_amount, 0)     as discount_amount,
    coalesce(tax_amount, 0)          as tax_amount
from {{ source('raw_sales', 'sales_orders') }}
