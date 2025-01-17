create database ecommerce;
use ecommerce;
-- Basic Queries
-- -1. List all unique cities where customers are located.
select * from customers;
select distinct customer_city from customers;

-- 2. Count the number of orders placed in 2017.
select * from orders;

select count(order_id) as total_orders_in_2017 from orders
where year(order_purchase_timestamp)=2017;


-- 3. Find the total sales per category.

select * from products;
select * from order_items;

select p1.product_category,sum(o.price) as total_price from products p1
join order_items o
on p1.product_id=o.product_id
group by p1.product_category;

-- 4. Calculate the percentage of orders that were paid in installments.
select * from payments;

select (sum(case when payment_installments>=1 then 1 else 0 end)/count(*) )*100 as percentage from payments;

-- 5. Count the number of customers from each state. 

select * from customers;

select customer_state ,count(customer_id)
from customers group by customer_state;

-- Calculate the number of orders per month in 2018.
select * from orders;
select month(order_purchase_timestamp) as month,count(order_id) as total_orders from orders
where year(order_purchase_timestamp)=2018
group by month(order_purchase_timestamp)
order by month(order_purchase_timestamp) asc;

-- Find the average number of products per order, grouped by customer city.

select * from order_items;
select * from orders;
select * from customers;
with count_per_order as(
select orders.order_id, orders.customer_id, count(order_items.order_id) as oc
from orders join order_items
on orders.order_id = order_items.order_id
group by orders.order_id, orders.customer_id
)
 select customers.customer_city, round(avg(count_per_order.oc),2) average_orders
from customers join count_per_order
on customers.customer_id = count_per_order.customer_id
group by customers.customer_city order by average_orders desc;

-- Calculate the percentage of total revenue contributed by each product category.

select * from order_items;
select * from products;

select * from payments;

select upper(products.product_category) category, 
round((sum(payments.payment_value)/(select sum(payment_value) from payments))*100,2) sales_percentage
from products join order_items 
on products.product_id = order_items.product_id
join payments 
on payments.order_id = order_items.order_id
group by category order by sales_percentage desc;



-- Identify the correlation between product price and the number of times a product has been purchased.

select products.product_category, 
count(order_items.product_id) as total_count,
round(avg(order_items.price),2) as avg_price
from products join order_items
on products.product_id = order_items.product_id
group by products.product_category;

-- Calculate the total revenue generated by each seller, and rank them by revenue.

select *, dense_rank() over(order by revenue desc) as rn from
(select order_items.seller_id, sum(payments.payment_value)
revenue from order_items join payments
on order_items.order_id = payments.order_id
group by order_items.seller_id) as a;

-- 1.Calculate the moving average of order values for each customer over their order history.
WITH cte AS (
    SELECT 
        orders.customer_id, 
        orders.order_purchase_timestamp, 
        payments.payment_value AS payment,
        AVG(payments.payment_value) OVER (
            PARTITION BY orders.customer_id 
            ORDER BY orders.order_purchase_timestamp 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS mov_avg
    FROM 
        payments 
    JOIN 
        orders ON payments.order_id = orders.order_id
)
SELECT 
    customer_id, 
    order_purchase_timestamp, 
    payment, 
    mov_avg
FROM 
    cte
ORDER BY 
    customer_id, 
    order_purchase_timestamp;


-- 2. Calculate the cumulative sales per month for each year.
select * from orders;
select * from payments;
WITH sales_data AS (
    SELECT 
        YEAR(orders.order_purchase_timestamp) AS years,
        MONTH(orders.order_purchase_timestamp) AS months,
        ROUND(SUM(payments.payment_value), 2) AS payment
    FROM 
        orders
    JOIN 
        payments ON orders.order_id = payments.order_id
    GROUP BY 
        YEAR(orders.order_purchase_timestamp), 
        MONTH(orders.order_purchase_timestamp)
    ORDER BY 
        YEAR(orders.order_purchase_timestamp), 
        MONTH(orders.order_purchase_timestamp)
),
cumulative_sales_data AS (
    SELECT
        years,
        months,
        payment,
        SUM(payment) OVER (ORDER BY years, months) AS cumulative_sales
    FROM
        sales_data
)
SELECT 
    years, 
    months, 
    payment, 
    cumulative_sales
FROM 
    cumulative_sales_data
ORDER BY 
    years, 
    months;


-- 3. Calculate the year-over-year growth rate of total sales.

WITH a AS (
    SELECT 
        YEAR(orders.order_purchase_timestamp) AS years,
        ROUND(SUM(payments.payment_value), 2) AS payment
    FROM 
        orders
    JOIN 
        payments ON orders.order_id = payments.order_id
    GROUP BY 
        YEAR(orders.order_purchase_timestamp)
    ORDER BY 
        YEAR(orders.order_purchase_timestamp)
),
percentage_change AS (
    SELECT 
        years,
        payment,
        ((payment - LAG(payment, 1) OVER (ORDER BY years)) /
        LAG(payment, 1) OVER (ORDER BY years)) * 100 AS percentage_change
    FROM 
        a
)
SELECT 
    years, 
    payment, 
    percentage_change
FROM 
    percentage_change
ORDER BY 
    years;


-- 4. Identify the top 3 customers who spent the most money in each year.

WITH customer_payments AS (
    SELECT 
        YEAR(orders.order_purchase_timestamp) AS years,
        orders.customer_id,
        SUM(payments.payment_value) AS payment,
        DENSE_RANK() OVER (
            PARTITION BY YEAR(orders.order_purchase_timestamp) 
            ORDER BY SUM(payments.payment_value) DESC
        ) AS d_rank
    FROM 
        orders 
    JOIN 
        payments ON payments.order_id = orders.order_id
    GROUP BY 
        YEAR(orders.order_purchase_timestamp),
        orders.customer_id
)
SELECT 
    years, 
    customer_id, 
    payment, 
    d_rank
FROM 
    customer_payments
WHERE 
    d_rank <= 3
ORDER BY 
    years, 
    d_rank;

