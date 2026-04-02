-- ============================================================================
-- STEP 1: Create database, schema, warehouse, and sample data
-- Run this script in any Snowflake account with SYSADMIN (or equivalent) role
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS TABLEAU_DEMO;
CREATE SCHEMA IF NOT EXISTS TABLEAU_DEMO.TABLEAU_AGENT_DEMO;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;
USE SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;

-- ---------------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID      INT,
    PRODUCT_NAME    VARCHAR(100),
    CATEGORY        VARCHAR(50),
    SUB_CATEGORY    VARCHAR(50),
    UNIT_PRICE      NUMBER(10,2)
);

INSERT INTO PRODUCTS VALUES
(1,  'Laptop Pro 15',       'Technology',   'Laptops',      1299.99),
(2,  'Wireless Mouse',      'Technology',   'Accessories',  29.99),
(3,  'Standing Desk',       'Furniture',    'Desks',        549.00),
(4,  'Ergonomic Chair',     'Furniture',    'Chairs',       399.00),
(5,  'Printer Ink Pack',    'Office',       'Supplies',     45.50),
(6,  'USB-C Hub',           'Technology',   'Accessories',  59.99),
(7,  'Bookshelf Oak',       'Furniture',    'Storage',      189.00),
(8,  'Notebook 3-Pack',     'Office',       'Supplies',     12.99),
(9,  'Monitor 27"',         'Technology',   'Monitors',     449.99),
(10, 'Webcam HD',           'Technology',   'Accessories',  79.99),
(11, 'Filing Cabinet',      'Furniture',    'Storage',      159.00),
(12, 'Whiteboard Markers',  'Office',       'Supplies',     8.99),
(13, 'Mechanical Keyboard', 'Technology',   'Accessories',  129.99),
(14, 'Desk Lamp LED',       'Furniture',    'Lighting',     69.99),
(15, 'Paper Ream 500ct',    'Office',       'Supplies',     6.49);

-- ---------------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID     INT,
    CUSTOMER_NAME   VARCHAR(100),
    SEGMENT         VARCHAR(30),
    REGION          VARCHAR(30),
    STATE           VARCHAR(50),
    CITY            VARCHAR(50)
);

INSERT INTO CUSTOMERS VALUES
(101, 'Acme Corp',           'Enterprise', 'West',    'California',    'San Francisco'),
(102, 'Global Industries',   'Enterprise', 'East',    'New York',      'New York City'),
(103, 'StartupXYZ',          'SMB',        'West',    'Washington',    'Seattle'),
(104, 'MidSize Solutions',   'Mid-Market', 'Central', 'Texas',         'Austin'),
(105, 'East Coast Trading',  'Enterprise', 'East',    'Massachusetts', 'Boston'),
(106, 'Mountain View LLC',   'SMB',        'West',    'California',    'Mountain View'),
(107, 'Heartland Services',  'Mid-Market', 'Central', 'Illinois',      'Chicago'),
(108, 'Southern Comfort Co', 'SMB',        'South',   'Georgia',       'Atlanta'),
(109, 'Pacific Rim Inc',     'Enterprise', 'West',    'Oregon',        'Portland'),
(110, 'Great Lakes Group',   'Mid-Market', 'Central', 'Michigan',      'Detroit');

-- ---------------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID        INT,
    CUSTOMER_ID     INT,
    ORDER_DATE      DATE,
    SHIP_DATE       DATE,
    SHIP_MODE       VARCHAR(30),
    ORDER_STATUS    VARCHAR(20)
);

INSERT INTO ORDERS VALUES
(1001, 101, '2025-01-15', '2025-01-18', 'Standard',  'Delivered'),
(1002, 102, '2025-01-22', '2025-01-25', 'Express',   'Delivered'),
(1003, 103, '2025-02-03', '2025-02-07', 'Standard',  'Delivered'),
(1004, 101, '2025-02-14', '2025-02-16', 'Express',   'Delivered'),
(1005, 104, '2025-03-01', '2025-03-05', 'Standard',  'Delivered'),
(1006, 105, '2025-03-10', '2025-03-12', 'Express',   'Delivered'),
(1007, 106, '2025-03-20', '2025-03-24', 'Economy',   'Delivered'),
(1008, 107, '2025-04-02', '2025-04-06', 'Standard',  'Delivered'),
(1009, 108, '2025-04-15', '2025-04-19', 'Standard',  'Delivered'),
(1010, 109, '2025-05-01', '2025-05-03', 'Express',   'Delivered'),
(1011, 110, '2025-05-12', '2025-05-16', 'Standard',  'Delivered'),
(1012, 101, '2025-06-01', '2025-06-04', 'Express',   'Delivered'),
(1013, 102, '2025-06-15', '2025-06-19', 'Standard',  'Delivered'),
(1014, 103, '2025-07-01', '2025-07-05', 'Economy',   'Delivered'),
(1015, 104, '2025-07-20', '2025-07-23', 'Express',   'Delivered'),
(1016, 105, '2025-08-05', '2025-08-08', 'Standard',  'Delivered'),
(1017, 106, '2025-08-18', '2025-08-22', 'Standard',  'Delivered'),
(1018, 107, '2025-09-01', '2025-09-04', 'Express',   'Delivered'),
(1019, 108, '2025-09-15', '2025-09-19', 'Economy',   'Delivered'),
(1020, 109, '2025-10-01', '2025-10-03', 'Express',   'Shipped'),
(1021, 110, '2025-10-10', '2025-10-14', 'Standard',  'Shipped'),
(1022, 101, '2025-11-01', '2025-11-04', 'Express',   'Processing'),
(1023, 102, '2025-11-15', '2025-11-19', 'Standard',  'Processing'),
(1024, 103, '2025-12-01', NULL,         'Economy',   'Pending'),
(1025, 104, '2025-12-10', NULL,         'Standard',  'Pending');

-- ---------------------------------------------------------------------------
-- Order Line Items
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ORDER_ITEMS (
    ORDER_ITEM_ID   INT,
    ORDER_ID        INT,
    PRODUCT_ID      INT,
    QUANTITY        INT,
    UNIT_PRICE      NUMBER(10,2),
    DISCOUNT        NUMBER(5,2)
);

INSERT INTO ORDER_ITEMS VALUES
(1, 1001, 1,  2,  1299.99, 0.00),
(2, 1001, 2,  5,  29.99,   0.10),
(3, 1002, 3,  1,  549.00,  0.00),
(4, 1002, 4,  3,  399.00,  0.05),
(5, 1003, 5,  10, 45.50,   0.00),
(6, 1003, 8,  20, 12.99,   0.15),
(7, 1004, 9,  2,  449.99,  0.00),
(8, 1004, 10, 4,  79.99,   0.00),
(9, 1005, 6,  3,  59.99,   0.00),
(10, 1005, 13, 2, 129.99,  0.10),
(11, 1006, 1,  1, 1299.99, 0.05),
(12, 1006, 14, 5, 69.99,   0.00),
(13, 1007, 7,  2, 189.00,  0.00),
(14, 1007, 15, 50,6.49,    0.20),
(15, 1008, 3,  2, 549.00,  0.00),
(16, 1008, 11, 1, 159.00,  0.00),
(17, 1009, 12, 30,8.99,    0.10),
(18, 1009, 5,  15,45.50,   0.00),
(19, 1010, 1,  3, 1299.99, 0.10),
(20, 1010, 9,  2, 449.99,  0.00),
(21, 1011, 4,  4, 399.00,  0.05),
(22, 1011, 14, 3, 69.99,   0.00),
(23, 1012, 2,  10,29.99,   0.15),
(24, 1012, 6,  5, 59.99,   0.00),
(25, 1013, 13, 3, 129.99,  0.00),
(26, 1013, 10, 6, 79.99,   0.10),
(27, 1014, 15, 100,6.49,   0.25),
(28, 1014, 8,  50,12.99,   0.20),
(29, 1015, 3,  1, 549.00,  0.00),
(30, 1015, 11, 2, 159.00,  0.00),
(31, 1016, 1,  2, 1299.99, 0.00),
(32, 1016, 4,  2, 399.00,  0.05),
(33, 1017, 7,  3, 189.00,  0.10),
(34, 1017, 12, 20,8.99,    0.00),
(35, 1018, 9,  1, 449.99,  0.00),
(36, 1018, 2,  8, 29.99,   0.00),
(37, 1019, 5,  20,45.50,   0.05),
(38, 1019, 15, 80,6.49,    0.15),
(39, 1020, 1,  4, 1299.99, 0.15),
(40, 1020, 13, 2, 129.99,  0.00),
(41, 1021, 3,  2, 549.00,  0.00),
(42, 1021, 6,  4, 59.99,   0.10),
(43, 1022, 9,  3, 449.99,  0.05),
(44, 1022, 10, 5, 79.99,   0.00),
(45, 1023, 14, 8, 69.99,   0.00),
(46, 1023, 4,  1, 399.00,  0.00),
(47, 1024, 2,  15,29.99,   0.20),
(48, 1024, 8,  30,12.99,   0.10),
(49, 1025, 11, 3, 159.00,  0.00),
(50, 1025, 7,  1, 189.00,  0.00);

-- Verify
SELECT 'PRODUCTS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM PRODUCTS
UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM CUSTOMERS
UNION ALL SELECT 'ORDERS', COUNT(*) FROM ORDERS
UNION ALL SELECT 'ORDER_ITEMS', COUNT(*) FROM ORDER_ITEMS;
