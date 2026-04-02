-- ============================================================================
-- STEP 2: Create a Semantic View over the sample data
-- This enables Cortex Analyst to translate natural language to SQL
-- ============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;

CREATE OR REPLACE SEMANTIC VIEW SALES_SEMANTIC_VIEW

  TABLES (
    products AS TABLEAU_DEMO.TABLEAU_AGENT_DEMO.PRODUCTS
        PRIMARY KEY (PRODUCT_ID)
        COMMENT = 'Product catalog with pricing and categories',

    customers AS TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CUSTOMERS
        PRIMARY KEY (CUSTOMER_ID)
        COMMENT = 'Customer master data with segmentation and geography',

    orders AS TABLEAU_DEMO.TABLEAU_AGENT_DEMO.ORDERS
        PRIMARY KEY (ORDER_ID)
        COMMENT = 'Order headers with dates, shipping, and status',

    order_items AS TABLEAU_DEMO.TABLEAU_AGENT_DEMO.ORDER_ITEMS
        PRIMARY KEY (ORDER_ITEM_ID)
        COMMENT = 'Order line items with product, quantity, price, and discount'
  )

  RELATIONSHIPS (
    orders      (CUSTOMER_ID) REFERENCES customers,
    order_items (ORDER_ID)    REFERENCES orders,
    order_items (PRODUCT_ID)  REFERENCES products
  )

  FACTS (
    order_items.QUANTITY   AS QUANTITY
        COMMENT = 'Number of units ordered per line item',

    order_items.UNIT_PRICE AS UNIT_PRICE
        COMMENT = 'Price per unit at time of order',

    order_items.DISCOUNT   AS DISCOUNT
        COMMENT = 'Discount percentage applied (0.0 to 1.0)',

    order_items.LINE_TOTAL AS (QUANTITY * UNIT_PRICE * (1 - DISCOUNT))
        COMMENT = 'Net revenue for the line item after discount'
  )

  DIMENSIONS (
    products.PRODUCT_NAME    AS PRODUCT_NAME
        WITH SYNONYMS = ('product', 'item name')
        COMMENT = 'Name of the product',

    products.CATEGORY        AS CATEGORY
        WITH SYNONYMS = ('product category', 'dept')
        COMMENT = 'Top-level product category: Technology, Furniture, Office',

    products.SUB_CATEGORY    AS SUB_CATEGORY
        WITH SYNONYMS = ('sub category', 'subcategory')
        COMMENT = 'Product sub-category within the main category',

    customers.CUSTOMER_NAME  AS CUSTOMER_NAME
        WITH SYNONYMS = ('customer', 'account name', 'company')
        COMMENT = 'Name of the customer or company',

    customers.SEGMENT        AS SEGMENT
        WITH SYNONYMS = ('customer segment', 'tier')
        COMMENT = 'Customer segment: Enterprise, Mid-Market, SMB',

    customers.REGION         AS REGION
        WITH SYNONYMS = ('sales region', 'territory')
        COMMENT = 'Geographic sales region: West, East, Central, South',

    customers.STATE          AS STATE
        WITH SYNONYMS = ('us state', 'province')
        COMMENT = 'US state where the customer is located',

    customers.CITY           AS CITY
        COMMENT = 'City where the customer is located',

    orders.ORDER_DATE        AS ORDER_DATE
        WITH SYNONYMS = ('date ordered', 'purchase date', 'order day')
        COMMENT = 'Date when the order was placed',

    orders.SHIP_MODE         AS SHIP_MODE
        WITH SYNONYMS = ('shipping method', 'delivery type')
        COMMENT = 'Shipping method: Standard, Express, Economy',

    orders.ORDER_STATUS      AS ORDER_STATUS
        WITH SYNONYMS = ('status', 'order state')
        COMMENT = 'Current order status: Delivered, Shipped, Processing, Pending'
  )

  METRICS (
    order_items.TOTAL_REVENUE AS SUM(order_items.LINE_TOTAL)
        WITH SYNONYMS = ('revenue', 'sales', 'total sales', 'gross revenue')
        COMMENT = 'Total revenue after discounts',

    order_items.TOTAL_QUANTITY AS SUM(order_items.QUANTITY)
        WITH SYNONYMS = ('units sold', 'items sold', 'volume')
        COMMENT = 'Total number of units sold',

    order_items.AVG_ORDER_VALUE AS AVG(order_items.LINE_TOTAL)
        WITH SYNONYMS = ('average order value', 'AOV', 'avg sale')
        COMMENT = 'Average line-item revenue',

    order_items.AVG_DISCOUNT AS AVG(order_items.DISCOUNT)
        WITH SYNONYMS = ('average discount', 'discount rate')
        COMMENT = 'Average discount percentage applied',

    orders.ORDER_COUNT AS COUNT(orders.ORDER_ID)
        WITH SYNONYMS = ('number of orders', 'total orders', 'order volume')
        COMMENT = 'Total number of orders',

    order_items.LINE_ITEM_COUNT AS COUNT(order_items.ORDER_ITEM_ID)
        WITH SYNONYMS = ('line items', 'item count')
        COMMENT = 'Total number of line items across orders'
  )

  COMMENT = 'Sales analytics semantic view for Tableau Cortex Agent demo'

  AI_SQL_GENERATION '
    When the user asks about revenue or sales, always use the TOTAL_REVENUE metric.
    When the user asks about top customers, rank by TOTAL_REVENUE descending.
    When asked about trends, group by ORDER_DATE at month granularity using DATE_TRUNC.
    Default time range is the full dataset (2025) unless the user specifies otherwise.
  '
;

-- Verify
DESCRIBE SEMANTIC VIEW SALES_SEMANTIC_VIEW;
