# Snowflake Cortex Agent + Tableau Integration Demo

> **This demo asset shows how to integrate a **Snowflake Cortex Agent** into a **Tableau dashboard** (or any BI tool) via a REST API middleware.**

## Architecture

```
Tableau Dashboard                 FastAPI Middleware              Snowflake
┌──────────────────┐    HTTP     ┌──────────────────┐   REST    ┌──────────────────┐
│  Embedded Chat   │ ────────── │  app.py          │ ──────── │  Cortex Agent    │
│  (HTML/JS panel) │  POST      │  /api/chat       │  agent   │  → Semantic View │
│                  │  /api/chat │                  │  :run    │  → SQL → Data    │
└──────────────────┘            └──────────────────┘          └──────────────────┘
```

The middleware can run **locally** or inside **Snowpark Container Services (SPCS)**.

## Files

| File | Purpose |
|------|---------|
| `01_setup_sample_data.sql` | Creates database, schema, and sample tables (Products, Customers, Orders, Order Items) |
| `02_create_semantic_view.sql` | Creates a Semantic View with dimensions, facts, metrics, and relationships |
| `03_create_cortex_agent.sql` | Creates the Cortex Agent backed by the Semantic View |
| `04_deploy_to_spcs.sql` | Sets up compute pool, image repo, and SPCS service |
| `app.py` | FastAPI middleware — auto-detects SPCS vs local for authentication |
| `static/index.html` | Chat UI (works standalone or embedded in Tableau via Web Page object) |
| `Dockerfile` | Container image for SPCS deployment |
| `service-spec.yaml` | SPCS service specification (also embedded in `04_deploy_to_spcs.sql`) |
| `requirements.txt` | Python dependencies |
| `.env.example` | Environment variable template (local mode only) |

## Setup Steps

### 1. Run SQL Scripts in Snowflake

Execute scripts **in order** in your Snowflake account (via Snowsight, SnowSQL, or any SQL client):

```
1. Run 01_setup_sample_data.sql
2. Run 02_create_semantic_view.sql
3. Run 03_create_cortex_agent.sql
```

> Adjust the `USE ROLE`, warehouse name, and database/schema if needed for your account.

---

## Deployment Option A: Run Locally

### 2a. Configure the Middleware

```bash
cp .env.example .env
# Edit .env with your Snowflake credentials
```

### 3a. Start the Middleware

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8501
```

Visit `http://localhost:8501` to test the chat UI.

---

## Deployment Option B: Deploy to SPCS

### 2b. Create Compute Pool and Image Repository

Run section **4a** and **4b** of `04_deploy_to_spcs.sql` in Snowflake:

```sql
-- Creates CORTEX_AGENT_POOL (CPU_X64_XS, 1 node)
-- Creates IMAGE_REPO in TABLEAU_DEMO.TABLEAU_AGENT_DEMO
```

Note the `repository_url` from:
```sql
SHOW IMAGE REPOSITORIES IN SCHEMA TABLEAU_DEMO.TABLEAU_AGENT_DEMO;
```

### 3b. Build and Push Docker Image

```bash
# Login to the Snowflake image registry
snow spcs image-registry login --connection <your_connection>

# Build for linux/amd64
docker build --platform linux/amd64 -t cortex-agent-middleware:latest .

# Tag with your registry URL
docker tag cortex-agent-middleware:latest <REPO_URL>/cortex-agent-middleware:latest

# Push
docker push <REPO_URL>/cortex-agent-middleware:latest
```

Replace `<REPO_URL>` with the repository URL from the SHOW command (e.g., `orgname-acctname.registry.snowflakecomputing.com/tableau_demo/tableau_agent_demo/image_repo`).

### 4b. Create the SPCS Service

Run section **4d** of `04_deploy_to_spcs.sql`:

```sql
CREATE SERVICE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE ...
```

### 5b. Get the Public URL

```sql
SHOW ENDPOINTS IN SERVICE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE;
-- The "ingress_url" column is your public chat UI URL
```

### Monitoring & Troubleshooting

```sql
-- Service status
SELECT SYSTEM$GET_SERVICE_STATUS('TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE');

-- Container logs
SELECT SYSTEM$GET_SERVICE_LOGS(
    'TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE', 0, 'cortex-agent-middleware'
);
```

### Grant Access to Other Roles

```sql
GRANT SERVICE ROLE TABLEAU_DEMO.TABLEAU_AGENT_DEMO.CORTEX_AGENT_SERVICE!ALL_ENDPOINTS_USAGE
    TO ROLE <consumer_role>;
```

---

## Embed in Tableau

### Option A: Web Page Object (Simplest)
1. Open your Tableau dashboard
2. Drag a **Web Page** object onto the dashboard
3. Enter the URL: `http://localhost:8501` (local) or the SPCS `ingress_url`
4. The chat panel appears inline in your dashboard

### Option B: Tableau Dashboard Extension
1. Package `static/index.html` as a [Tableau Dashboard Extension](https://tableau.github.io/extensions-api/)
2. Add a `manifest.trex` file pointing to your hosted URL
3. Install the extension in Tableau Desktop/Server

### Option C: URL Action
1. Add a **URL Action** to your dashboard
2. Point it to `http://your-server:8501/?q=<PARAMETER>`
3. Pass Tableau parameters to pre-populate questions

## Sample Questions to Ask

- "What is the total revenue by product category?"
- "Who are the top 5 customers by total sales?"
- "Show monthly revenue trend for 2025"
- "What is the revenue split by region?"
- "How many orders are still pending?"
- "What is the average discount by customer segment?"

## How SPCS Auth Works

When deployed to SPCS, the app auto-detects its environment:
- **SPCS**: Reads an OAuth token from `/snowflake/session/token` (auto-provided by Snowflake). Uses `SNOWFLAKE_HOST` and `SNOWFLAKE_ACCOUNT` env vars (auto-set by SPCS).
- **Local**: Uses `SNOWFLAKE_USER` / `SNOWFLAKE_PASSWORD` from `.env` to obtain a session token via the Snowflake connector.

No code changes are needed between the two modes.

## Customization

### Change the Agent
Edit `03_create_cortex_agent.sql` to modify:
- **Instructions**: Change the `response` and `orchestration` instructions
- **Tools**: Add more semantic views or Cortex Search services
- **Model**: Change `"orchestration": "auto"` to a specific model

### Change the UI
Edit `static/index.html` to:
- Modify colors/branding to match your dashboard theme
- Add/remove suggested question buttons
- Customize the table and chart rendering

### Production Deployment
For production use:
- Deploy to **SPCS** (recommended) for managed auth and networking
- Use **key-pair authentication** if running locally
- Add **rate limiting** and **authentication** to the `/api/chat` endpoint
- Use **Snowflake OAuth** for multi-user access
