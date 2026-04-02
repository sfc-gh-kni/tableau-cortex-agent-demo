-- ============================================================================
-- STEP 3: Create a Cortex Agent that uses the Semantic View
-- ============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;

CREATE OR REPLACE AGENT TABLEAU_DEMO.TABLEAU_AGENT_DEMO.SALES_AGENT
FROM SPECIFICATION
$$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 120
    tokens: 100000

instructions:
  response: "You are a sales analytics assistant embedded in a Tableau dashboard. Respond concisely with data-driven answers. When presenting numbers, format them with commas and 2 decimal places for currency. Always mention the time period covered by the data."
  orchestration: "Use the sales_data tool for all questions about revenue, orders, customers, products, shipping, or any sales-related metrics."

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: sales_data
      description: "Query sales data including revenue, orders, customers, products, categories, regions, and shipping information."

tool_resources:
  sales_data:
    semantic_view: "TABLEAU_DEMO.TABLEAU_AGENT_DEMO.SALES_SEMANTIC_VIEW"
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
      query_timeout: 60
$$;

-- Verify the agent was created
SHOW AGENTS LIKE 'SALES_AGENT' IN SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;
DESCRIBE AGENT TABLEAU_DEMO.TABLEAU_AGENT_DEMO.SALES_AGENT;

-- Quick test via SQL (optional)
-- SELECT SNOWFLAKE.CORTEX.AGENT_RUN(
--     'TABLEAU_DEMO.TABLEAU_AGENT_DEMO.SALES_AGENT',
--     'What is the total revenue by product category?'
-- );
