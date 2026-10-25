{{ config(materialized='semantic_view') }}

TABLES (
    orders AS {{ ref('fct_sales_order') }}
        PRIMARY KEY (order_line_id),
    products AS {{ ref('dim_product') }}
        PRIMARY KEY (product_id)
)

RELATIONSHIPS (
    orders_to_products AS orders (product_id) REFERENCES products
)

FACTS (
    orders.net_revenue AS net_revenue
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'net_revenue') }},
    orders.quantity_sold AS quantity_sold
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'quantity_sold') }},
    orders.discount_amount AS discount_amount
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'discount_amount') }},
    orders.confirmed_order_id AS confirmed_order_id
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'confirmed_order_id') }}
)

DIMENSIONS (
    products.product_name AS product_name
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'product_name') }},
    products.product_category AS product_category
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'product_category') }},
    products.product_brand AS product_brand
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'product_brand') }},
    orders.order_date AS order_date
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'order_date') }},
    orders.order_status AS order_status
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'order_status') }}
)

METRICS (
    orders.total_revenue AS SUM(orders.net_revenue)
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'total_revenue') }},
    orders.total_quantity AS SUM(orders.quantity_sold)
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'total_quantity') }},
    orders.total_discount AS SUM(orders.discount_amount)
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'total_discount') }},
    orders.total_orders AS COUNT(DISTINCT orders.confirmed_order_id)
        COMMENT = {{ get_semantic_description('sales_semantic_view', 'total_orders') }}
)

COMMENT = 'Sales order analytics by product'
