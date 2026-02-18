# Cleaning data
# convert datetime from text to datetime. 
# all the time in orders columns are 0, so only extract date
alter table orders add column OrderDateUpdated date, add column RequiredDateUpdated date, add column ShippedDateUpdated date;
update orders
set OrderDateUpdated = date(str_to_date(OrderDate, '%Y-%m-%d %H:%i:%s')),
RequiredDateUpdated = date(str_to_date(RequiredDate, '%Y-%m-%d %H:%i:%s')),
ShippedDateUpdated = date(str_to_date(ShippedDate, '%Y-%m-%d %H:%i:%s'));

select OrderDate, OrderDateUpdated,
RequiredDate, RequiredDateUpdated,
ShippedDate, ShippedDateUpdated
from orders;

alter table orders drop column OrderDate,
drop column RequiredDate,
drop column ShippedDate;
 
 # 1. Change over time
 select date_format(OrderDateUpdated, '%Y-%m') as order_month,
 round(sum(total_sales),2) as total_amount_sales,
 count(distinct CustomerID) as total_customers,
 count(distinct orders.OrderID) as total_orders,
 sum(quantity) as total_product_quantity
 from orders
 join (select OrderID, sum(Quantity) as quantity, sum(UnitPrice * Quantity) as total_sales
 from order_details
 group by OrderID) orderID_sales
 on orderID_sales.OrderID = orders.OrderID
 group by date_format(OrderDateUpdated, '%Y-%m');
 
 # 2. Cumulative Analysis - to identify whether the business is growing or declining over months
 with orderID_sales as (select OrderID, sum(Quantity) as quantity, sum(UnitPrice * Quantity) as total_sales
 from order_details
 group by OrderID)
 select order_month,
 round(amount,2) as amount,
 round(sum(amount) over (order by order_month),2) as total_amount
 from(
 select date_format(OrderDateUpdated, '%Y-%m') as order_month,
 sum(total_sales) as amount
 from orders
 join orderID_sales on orderID_sales.OrderID = orders.OrderID
 group by date_format(OrderDateUpdated, '%Y-%m')) temp;
 
 # 3. year-to-year change
 with orderID_sales as (select OrderID, sum(Quantity) as quantity, sum(UnitPrice * Quantity) as total_sales
 from order_details
 group by OrderID)
 select order_year,
 round(amount,2) as sales,
 round(sum(amount) over (order by order_year),2) as total_sales,
 round(amount - lag(amount) over (order by order_year),2) as year_to_year_change
 from(
 select date_format(OrderDateUpdated, '%Y') as order_year,
 sum(total_sales) as amount
 from orders
 join orderID_sales on orderID_sales.OrderID = orders.OrderID
 group by date_format(OrderDateUpdated, '%Y')) temp
 order by order_year;
 
 # performance analysis - compare current sales in a particular year of each product to average sales and past year sales
 with year_sales as(select order_year, products.ProductID as ProductID, ProductName, round(sum(order_details.UnitPrice * order_details.Quantity),2) as sales
 from products
 join order_details on order_details.ProductID = products.ProductID
 join (select OrderID, year(OrderDateUpdated) as order_year
 from orders) temp on temp.OrderID = order_details.OrderID
 group by products.ProductID, products.ProductName, order_year),
 average_product_sales as(
 select ProductID, round(avg(sales),2) as average_sales
 from year_sales
 group by ProductID)
 select order_year, year_sales.ProductID, ProductName, sales, average_sales,
 round(sales- average_sales,2) as diff_avg,
 round(lag(sales) over (partition by year_sales.ProductID order by order_year),2) as prev_year_sales,
 round((sales - lag(sales) over (partition by year_sales.ProductID order by order_year)),2) as prev_year_sales_diff
 from year_sales
 join average_product_sales on average_product_sales.ProductID = year_sales.ProductID;
 
 # 4. Part-To-Whole Analysis --> which categories contribute most to the sales
 select * from categories;
 select * from products;
 select * from orders;
 select * from order_details;
 
 with category_sales as(select CategoryName, round(sum(o.UnitPrice * o.Quantity),2) as total_sales
 from order_details o
 join products p on p.ProductID = o.ProductID
 join categories c on c.CategoryID = p.CategoryID
 group by CategoryName)
 select CategoryName, total_sales,
 concat(round(total_sales/ sum(total_sales) over() *100, 0), '%') as contribution_percent
 from category_sales
 order by total_sales desc;
 
 #5. Data Segmentation
 /* segment products into cost ranges and count how many products */
 with product_segment as(
 select ProductID, ProductName, UnitPrice,
 case when UnitPrice < 30 then 'below 30'
 when UnitPrice between 30 and 50 then '30-50'
 when UnitPrice between 50 and 100 then '50-100'
 else 'above 100' end cost_range
 from products)
 select cost_range, count(distinct ProductID) as num_of_products
 from product_segment
 group by cost_range
 order by num_of_products;
 
 /* grouping customer by spending behaviors into three groups
 - VIP: Customers with at least 12 months of history and total spending > 10000
 - Regular: Customers with at least 12 months of history and total spending below 10000
 - New: Customer swith life span less than 12 months*/
with customer_segment as (
 select CustomerID, round(sum(s.total_spending),0) as spending,
 timestampdiff(month, min(OrderDateUpdated), max(OrderDateUpdated)) as lifespan
 from orders
 join
 (select orderID, round(sum(UnitPrice * Quantity),1) as total_spending
 from order_details
 group by orderID) s on s.OrderID = orders.OrderID
 group by CustomerID)
 select 
 case when spending >= 10000 and lifespan >= 12 then 'VIP'
 when spending <10000 and lifespan >= 12 then 'Regular'
 else 'New' end customer_type,
 count(customerID) as number_of_customers
 from customer_segment
 group by customer_type
 order by customer_type desc;
 
 # 6. Build Customer Report
 /* This report highlights:
 1. Customer's essential information such as name, country, transaction details
 2. Cusomer segmentation into 2 categories VIP, Regular, New
 3. Customer-level metrics
    - total orders
    - total spending
    - total quantity purchased
    - total products purchased
    - life span in months
4. Calculate valuable KPIs:
    - recency (months since last order)
    - average order value
    - average monthly spending */

create view report_customer as
with customer_report as(
select orders.CustomerID, ContactName, Country, count(distinct orders.OrderID) as total_orders,
sum(total_products) as num_products, sum(total_quantity) as num_quantity,
sum(total_spending) as spending, max(OrderDateUpdated) as last_order,
min(OrderDateUpdated) as first_order
from orders
join(
select OrderID, count(distinct ProductID) as total_products, 
sum(Quantity) as total_quantity,
sum(UnitPrice * Quantity) as total_spending
from order_details
group by OrderID) o on o.OrderID = orders.OrderID
join customers c on c.CustomerID = orders.CustomerID
group by orders.CustomerID, ContactName, Country)
select CustomerID, ContactName, Country, 
case when spending >= 10000 and timestampdiff(month, first_order, last_order) >= 12 then 'VIP'
 when spending <10000 and timestampdiff(month, first_order, last_order) >= 12 then 'Regular'
 else 'New' end customer_type,
 timestampdiff(month, first_order, last_order) as lifespan,
 total_orders, num_products, num_quantity, round(spending,0) as total_spending, last_order,
 timestampdiff(month, last_order, curdate()) as recency,
 round(spending/total_orders,0) as avg_spent_per_order,
 case when timestampdiff(month, last_order, curdate()) = 0 then spending
 else round(spending/timestampdiff(month, last_order, curdate()), 0) end avg_spent_per_month 
from customer_report;

/* 7. Product Report
This report highlights
1. Product's important information such as name, category, cost
2. Product segmentation by revenue to identify High-Performer, Mid-Performer, Low-Performer
3. Aggregates product-level metrics
   - total revenue
   - total orders
   - total quantity sold
   - total customers (unique)
   - lifespan (in months)
4. Calculate valuable KPIs:
   - recency (months since last sale)
   - average order revenue (AOR)
   - average monthly revenue */


create view report_product as
with product_report as(
select p.productID, p.ProductName, c.CategoryName, s.CompanyName, s.Country, p.UnitPrice, sum(Quantity) as total_quantity_sold, 
sum(order_details.UnitPrice * Quantity) as total_revenue, count(distinct orders.OrderID) as total_order,
count(distinct customerID) as total_customers,
max(OrderDateUpdated) as last_order,
timestampdiff(month, min(OrderDateUpdated), max(OrderDateUpdated)) as lifespan,
UnitsInStock, UnitsOnOrder, ReorderLevel, Discontinued
from order_details
join orders on orders.OrderID = order_details.OrderID
join products p on p.ProductID = order_details.ProductID
join categories c on c.CategoryID = p.CategoryID
join suppliers s on s.SupplierID = p.SupplierID
group by p.productID, p.ProductName, c.CategoryName, s.CompanyName, s.Country, p.UnitPrice, UnitsInStock, UnitsOnOrder, ReorderLevel, Discontinued)
select *, 
case when total_revenue > 10000 then 'High-Performer'
when total_revenue between 5000 and 10000 then 'Middle-Performer'
else 'Low-Performer' end product_type,
round(total_revenue/total_order,0) as avg_revenue_per_order,
round(total_revenue/timestampdiff(month, last_order, curdate()),0) as avg_revenue_per_month,
timestampdiff(month, last_order, curdate()) as recency,
case when UnitsInStock + UnitsOnOrder < ReorderLevel and Discontinued = 0 then 'Reorder'
else 'No reorder' end Actions
from product_report;

/* 5. The most hard-working employee and shipper
1. Employee report 
- personal information such as full name, country, gender, age
- the number of orders they worked
- the number of years they have been working with the company
- the salary compared to the average salary
- identify whether they are High/Middle/Low Performers
- the average number of orders they worked in a year*/
alter table employees add column BirthDateUpdated date, add column HireDateUpdated date;
update employees set BirthDateUpdated = date(str_to_date(BirthDate, '%m/%d/%Y %H:%i')),
HireDateUpdated = date(str_to_date(HireDate, '%m/%d/%Y %H:%i'));

create view report_employee as
with employee_report as(
select e.EmployeeID, 
concat(e.LastName, ' ', e.FirstName) as EmployeeName,
TitleOfCourtesy, Title, timestampdiff(year, BirthDateUpdated, curdate()) as Age, Country,
timestampdiff(year, HireDateUpdated, curdate()) as WorkingTime,
count(distinct OrderID) as NumOrders, Salary, 
round(Salary - avg(Salary) over(),2) as AvgSalaryCompare
from orders o
left join employees e on e.EmployeeID = o.EmployeeID
group by e.EmployeeID, LastName, FirstName, TitleOfCourtesy, Title, Country, Salary, BirthDateUpdated, HireDateUpdated)
select *, 
case when round(NumOrders/3,0) >= 50 then 'High'
when round(NumOrders/3,0) between 30 and 50 then 'Middle'
else 'Low' end EmployeePerformance,
round(NumOrders/3,0) as AvgOrdersPerYear
from employee_report;

/* Shipper report
- essential information such as ShipperID, Company Name and Phone
- Number of Orders delivered and OnTimeDeliveryRate*/
with report_order as(
select *, case when ShippedDateUpdated > RequiredDateUpdated then 'Late Delivery'
else 'On-Time Delivery' end DeliveryTime
from orders)
select ShipperID, CompanyName, Phone, year(OrderDateUpdated) as OrderYear, count(distinct OrderID) as NumOrdersDelivered,
sum(case when DeliveryTime = 'On-Time Delivery' then 1 else 0 end) as NumOnTimeDeliver,
sum(case when DeliveryTime = 'Late Delivery' then 1 else 0 end) as NumLateDeliver,
round(sum(case when DeliveryTime = 'On-Time Delivery' then 1 else 0 end) / count(distinct OrderID) * 100,2) as OnTimeDeliveryRate
from report_order r
left join shippers on r.ShipVia = shippers.ShipperID
group by ShipperID, CompanyName, Phone, OrderYear
order by ShipperID;

create view report_shipper as
with report_order as(
select *, case when ShippedDateUpdated > RequiredDateUpdated then 'Late Delivery'
else 'On-Time Delivery' end DeliveryTime
from orders)
select ShipperID, CompanyName, Phone, count(distinct OrderID) as NumOrdersDelivered,
sum(case when DeliveryTime = 'On-Time Delivery' then 1 else 0 end) as NumOnTimeDeliver,
sum(case when DeliveryTime = 'Late Delivery' then 1 else 0 end) as NumLateDeliver,
round(sum(case when DeliveryTime = 'On-Time Delivery' then 1 else 0 end) / count(distinct OrderID) * 100,2) as OnTimeDeliveryRate
from report_order r
left join shippers on r.ShipVia = shippers.ShipperID
group by ShipperID, CompanyName, Phone
order by ShipperID;








 
 
 
 
 
 
 
 
 







 
 
 
 
 
 
 
 
 