-- ============================================================================
-- STEP 4: Deploy the middleware to Snowpark Container Services (SPCS)
-- Run AFTER steps 01-03 (sample data, semantic view, agent)
-- ============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;

-- ---------------------------------------------------------------------------
-- 4a. Create a compute pool (skip if you already have one)
-- ---------------------------------------------------------------------------
CREATE COMPUTE POOL IF NOT EXISTS CORTEX_AGENT_POOL
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 300;

-- Wait for the pool to be ready
DESCRIBE COMPUTE POOL CORTEX_AGENT_POOL;

-- ---------------------------------------------------------------------------
-- 4b. Create an image repository
-- ---------------------------------------------------------------------------
CREATE IMAGE REPOSITORY IF NOT EXISTS TABLEAU_DEMO.TABLEAU_AGENT_DEMO.IMAGE_REPO;

-- Get the repository URL (you'll need this for docker push)
SHOW IMAGE REPOSITORIES IN SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;
-- Note the "repository_url" column value, e.g.:
-- <orgname>-<acctname>.registry.snowflakecomputing.com/tableau_demo/tableau_agent_demo/image_repo

-- ---------------------------------------------------------------------------
-- 4c. Build and push the Docker image (run these in your local terminal)
-- ---------------------------------------------------------------------------
-- Replace <REPO_URL> with the repository_url from the SHOW command above.
--
-- # Step 1: Login to registry
-- snow spcs image-registry login --connection <your_connection>
--
-- # Step 2: Build for linux/amd64
-- docker build --platform linux/amd64 -t cortex-agent-middleware:latest .
--
-- # Step 3: Tag
-- docker tag cortex-agent-middleware:latest <REPO_URL>/cortex-agent-middleware:latest
--
-- # Step 4: Push
-- docker push <REPO_URL>/cortex-agent-middleware:latest

-- ---------------------------------------------------------------------------
-- 4d. Create the SPCS service
-- ---------------------------------------------------------------------------
CREATE SERVICE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE
    IN COMPUTE POOL CORTEX_AGENT_POOL
    FROM SPECIFICATION $$
spec:
  containers:
  - name: cortex-agent-middleware
    image: /TABLEAU_DEMO/TABLEAU_AGENT_DEMO/IMAGE_REPO/cortex-agent-middleware:latest
    env:
      SNOWFLAKE_WAREHOUSE: "COMPUTE_WH"
      SNOWFLAKE_DATABASE: "TABLEAU_DEMO"
      SNOWFLAKE_SCHEMA: "TABLEAU_AGENT_DEMO"
      AGENT_NAME: "SALES_AGENT"
    resources:
      requests:
        memory: 512Mi
        cpu: 500m
      limits:
        memory: 1Gi
        cpu: 1000m
    readinessProbe:
      port: 8080
      path: /api/health
  endpoints:
  - name: chat-ui
    port: 8080
    public: true
    $$
    MIN_INSTANCES = 1
    MAX_INSTANCES = 1
    QUERY_WAREHOUSE = COMPUTE_WH;

-- ---------------------------------------------------------------------------
-- 4e. Monitor deployment
-- ---------------------------------------------------------------------------

-- Check service status (wait for READY)
SELECT SYSTEM$GET_SERVICE_STATUS('TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE');

-- Get the public endpoint URL
SHOW ENDPOINTS IN SERVICE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE;
-- Note the "ingress_url" column — this is your public chat UI URL!

-- Check logs if something goes wrong
SELECT SYSTEM$GET_SERVICE_LOGS(
    'TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE',
    0,
    'cortex-agent-middleware'
);

-- ---------------------------------------------------------------------------
-- 4f. Grant access to other roles (optional)
-- ---------------------------------------------------------------------------
-- GRANT SERVICE ROLE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE!ALL_ENDPOINTS_USAGE
--     TO ROLE <consumer_role>;

-- ---------------------------------------------------------------------------
-- Cleanup (when done with the demo)
-- ---------------------------------------------------------------------------
-- DROP SERVICE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE;
-- DROP COMPUTE POOL CORTEX_AGENT_POOL;
