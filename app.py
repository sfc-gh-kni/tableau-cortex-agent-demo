import os
import json
import logging
from typing import Optional

import requests
import snowflake.connector
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Cortex Agent Tableau Middleware")

cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_HOST = os.getenv("SNOWFLAKE_HOST")
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.getenv("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ROLE = os.getenv("SNOWFLAKE_ROLE", "SYSADMIN")
SNOWFLAKE_WAREHOUSE = os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
SNOWFLAKE_DATABASE = os.getenv("SNOWFLAKE_DATABASE", "TABLEAU_DEMO")
SNOWFLAKE_SCHEMA = os.getenv("SNOWFLAKE_SCHEMA", "TABLEAU_AGENT_DEMO")
AGENT_NAME = os.getenv("AGENT_NAME", "SALES_AGENT")

SPCS_TOKEN_PATH = "/snowflake/session/token"


def _is_running_in_spcs() -> bool:
    return os.path.exists(SPCS_TOKEN_PATH)


def _get_spcs_login_token() -> str:
    with open(SPCS_TOKEN_PATH, "r") as f:
        return f.read()


def _call_agent(messages: list) -> dict:
    if _is_running_in_spcs():
        return _call_agent_spcs(messages)
    return _call_agent_local(messages)


def _call_agent_spcs(messages: list) -> dict:
    conn = snowflake.connector.connect(
        host=SNOWFLAKE_HOST,
        account=SNOWFLAKE_ACCOUNT,
        token=_get_spcs_login_token(),
        authenticator="oauth",
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA,
    )
    session_token = conn.rest.token
    host = SNOWFLAKE_HOST
    url = (
        f"https://{host}/api/v2/databases/{SNOWFLAKE_DATABASE}"
        f"/schemas/{SNOWFLAKE_SCHEMA}/agents/{AGENT_NAME}:run"
    )
    headers = {
        "Authorization": f'Snowflake Token="{session_token}"',
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload = {"messages": messages, "stream": False}
    logger.info(f"[SPCS] Calling agent at {url}")
    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=120)
    finally:
        conn.close()
    logger.info(f"[SPCS] Response status: {resp.status_code}")
    if resp.status_code != 200:
        logger.error(f"[SPCS] Agent error: {resp.text[:1000]}")
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    return resp.json()


def _call_agent_local(messages: list) -> dict:
    conn = snowflake.connector.connect(
        account=SNOWFLAKE_ACCOUNT,
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        role=SNOWFLAKE_ROLE,
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA,
        session_parameters={"PYTHON_CONNECTOR_QUERY_RESULT_FORMAT": "json"},
    )
    token = conn.rest.token
    account_parts = SNOWFLAKE_ACCOUNT.replace("_", "-").split(".")
    host = f"{account_parts[0]}.snowflakecomputing.com"
    url = (
        f"https://{host}/api/v2/databases/{SNOWFLAKE_DATABASE}"
        f"/schemas/{SNOWFLAKE_SCHEMA}/agents/{AGENT_NAME}:run"
    )
    headers = {
        "Authorization": f'Snowflake Token="{token}"',
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload = {"messages": messages, "stream": False}
    logger.info(f"[Local] Calling agent at {url}")
    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=120)
    finally:
        conn.close()
    logger.info(f"[Local] Response status: {resp.status_code}")
    if resp.status_code != 200:
        logger.error(f"[Local] Agent error: {resp.text[:1000]}")
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    return resp.json()


class ChatRequest(BaseModel):
    question: str
    conversation_history: Optional[list] = None


class ChatResponse(BaseModel):
    answer: str
    sql: Optional[str] = None
    data: Optional[list] = None
    chart_spec: Optional[str] = None


@app.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    messages = []
    if req.conversation_history:
        messages.extend(req.conversation_history)
    messages.append({
        "role": "user",
        "content": [{"type": "text", "text": req.question}],
    })

    try:
        body = _call_agent(messages)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Agent call failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    logger.info(f"Agent response keys: {list(body.keys())}")
    logger.info(f"Agent response: {json.dumps(body, default=str)[:3000]}")

    answer_text = ""
    sql_text = None
    data_rows = None
    chart_spec = None

    for item in body.get("content", []):
        item_type = item.get("type", "")

        if item_type == "text":
            answer_text += item.get("text", "")

        elif item_type == "tool_result":
            tr = item.get("tool_result", {})
            for c in tr.get("content", []):
                if c.get("type") == "json":
                    j = c.get("json", {})
                    if "sql" in j:
                        sql_text = j["sql"]
                    if "text" in j and not answer_text:
                        answer_text = j["text"]
                    rs = j.get("result_set", {})
                    if rs.get("data"):
                        cols = [
                            col["name"]
                            for col in rs.get("resultSetMetaData", {}).get("rowType", [])
                        ]
                        data_rows = [dict(zip(cols, row)) for row in rs["data"]]

        elif item_type == "chart":
            chart_info = item.get("chart", {})
            raw_spec = chart_info.get("chart_spec")
            if raw_spec:
                chart_spec = raw_spec if isinstance(raw_spec, str) else json.dumps(raw_spec)
                logger.info(f"Chart spec (first 500): {chart_spec[:500]}")

        elif item_type == "table":
            rs = item.get("result_set", {})
            if rs.get("data") and not data_rows:
                cols = [
                    col["name"]
                    for col in rs.get("resultSetMetaData", {}).get("rowType", [])
                ]
                data_rows = [dict(zip(cols, row)) for row in rs["data"]]

    if not answer_text:
        answer_text = "I received a response but couldn't extract a text answer."

    return ChatResponse(
        answer=answer_text,
        sql=sql_text,
        data=data_rows,
        chart_spec=chart_spec,
    )


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "agent": f"{SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{AGENT_NAME}",
        "running_in_spcs": _is_running_in_spcs(),
    }


@app.post("/api/debug")
def debug(req: ChatRequest):
    messages = [{"role": "user", "content": [{"type": "text", "text": req.question}]}]
    try:
        body = _call_agent(messages)
        return {"status_code": 200, "body": body}
    except HTTPException as e:
        return {"status_code": e.status_code, "body": e.detail}
    except Exception as e:
        return {"status_code": 500, "body": str(e)}


app.mount("/", StaticFiles(directory="static", html=True), name="static")
