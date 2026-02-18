# 📊 SQL Exploratory Data Analysis (EDA) Project

## 📌 Overview
This project focuses on performing **Exploratory Data Analysis (EDA) using SQL** to extract key business insights from a structured database. By leveraging SQL queries, I analyzed various aspects including sales trends, customer behavior, employee performance, delivery efficiency and product report to uncover actionable inshights.

## 🎯 Key Objectives
- Perform data cleaning and preprocessing using SQL.
- Extract sales, customers, suppliers, products and delivery insights from a relational database.
- Utilize aggregation, joins, window functions, and CTEs.

 ## 🗄 Database Schema
The dataset includes key relational tables such as:
- Customers: Contains customer information (ID, Name, Contact Name, Address,...)
- Orders: Track order ID, order date, customer IDs, employee IDs, shipper IDs anf country.
- Order_details: Specify products sold in the order with Unit Price and Quantity
- Products: Stores product details (ID, Category, UnitPrice, Supplier, Name,..)
- Suppliers: Stores details of product suppliers such as SupplierID, Country,..
- Employees: Contains employee essential information icluding Name, Employee ID, Birth Date, Hire Date,...

## 📊 Key Insights
- Overall on-time delivery rate exceeded 95%. Performance variation highlights operational differences among shippers. United Package experienced a performance drop to 92.81% in 1997. Federal Shipping improved significantly to 98.67% in 1998.
- Beverages is the best-selling categories, followed by meat/poultry.

## 🛠 Tools & Technologies
- SQL (MySQL)
  - Aggregate Functions (SUM, AVG, COUNT, MAX,...)
  - Joins (INNER JOIN, LEFT JOIN, RIGHT JOIN)
  - Window Functions (ROW_NUMBER(), LAG(),...)
  - Common Table Expressions CTEs
  - Subqueries and Nested Queries
  - Group By & Having Clauses
  - Case Statements for Conditional Analysis


