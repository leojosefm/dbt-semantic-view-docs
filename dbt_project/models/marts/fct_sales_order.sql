-- One row per sales order line.
-- Cancelled lines are kept (for status analysis) but contribute zero to measures.
with lines as (

    select * from {{ ref('stg_sales_orders') }}

)

select
    order_line_id,
    order_id,
    customer_id,
    product_id,
    order_date,
    order_status,

    -- measures: zeroed for cancelled lines
    iff(order_status = 'CANCELLED', 0, quantity)                                    as quantity_sold,
    iff(order_status = 'CANCELLED', 0, discount_amount)                             as discount_amount,
    iff(order_status = 'CANCELLED', 0, quantity * unit_price - discount_amount)     as net_revenue,

    -- null for cancelled lines so COUNT(DISTINCT ...) counts confirmed orders only
    iff(order_status = 'CANCELLED', null, order_id)                                 as confirmed_order_id
from lines
