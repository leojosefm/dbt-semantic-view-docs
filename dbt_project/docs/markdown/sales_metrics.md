{% docs sem_net_revenue %}
Line revenue after discounts, excluding tax. Cancelled order lines contribute zero.
{% enddocs %}

{% docs sem_quantity_sold %}
Units sold on the order line. Cancelled order lines contribute zero.
{% enddocs %}

{% docs sem_discount_amount %}
Discount value applied to the order line. Cancelled order lines contribute zero.
{% enddocs %}

{% docs sem_confirmed_order_id %}
Sales order identifier, populated only for non-cancelled lines. Used to count distinct confirmed orders.
{% enddocs %}

{% docs sem_total_revenue %}
Total net revenue from confirmed sales orders: quantity multiplied by unit price, less discounts, excluding tax and cancelled orders.
{% enddocs %}

{% docs sem_total_quantity %}
Total units sold across confirmed sales orders, excluding cancelled orders.
{% enddocs %}

{% docs sem_total_discount %}
Total discount value given on confirmed sales orders.
{% enddocs %}

{% docs sem_total_orders %}
Number of distinct confirmed sales orders. An order with several lines is counted once. Cancelled orders are excluded.
{% enddocs %}

{% docs sem_order_date %}
Date the customer placed the sales order.
{% enddocs %}

{% docs sem_order_status %}
Current lifecycle status of the sales order, such as CONFIRMED, SHIPPED, or CANCELLED.
{% enddocs %}
