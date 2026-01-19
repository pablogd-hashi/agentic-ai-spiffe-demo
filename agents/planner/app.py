"""
Planner Agent

Entry point for user questions. Routes requests to the executor-agent.

This agent does NOT call Ollama directly. It demonstrates identity-based
communication by calling the executor with its assigned SPIFFE identity.

The Consul Connect sidecar handles mTLS. The app code sees plain HTTP.
"""

import os
import logging
from flask import Flask, request, jsonify
import requests

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Executor agent address
# In Consul Connect, services communicate via localhost to their sidecar
# The sidecar proxies to the remote service's sidecar over mTLS
EXECUTOR_HOST = os.getenv("EXECUTOR_HOST", "localhost")
EXECUTOR_PORT = os.getenv("EXECUTOR_PORT", "9001")
EXECUTOR_URL = f"http://{EXECUTOR_HOST}:{EXECUTOR_PORT}/execute"


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for Consul."""
    return jsonify({"status": "healthy"}), 200


@app.route("/ask", methods=["POST"])
def ask():
    """
    Accept a user question and route it to the executor-agent.

    Request body:
    {
        "question": "What is SPIFFE?"
    }

    Response:
    {
        "answer": "...",
        "source": "executor-agent"
    }
    """
    data = request.get_json()

    if not data or "question" not in data:
        logger.error("Invalid request: missing 'question' field")
        return jsonify({"error": "Missing 'question' field"}), 400

    question = data["question"]
    logger.info(f"Received question: {question}")

    # Call the executor-agent
    # The sidecar intercepts this and establishes mTLS to executor's sidecar
    try:
        logger.info(f"Forwarding to executor at {EXECUTOR_URL}")
        response = requests.post(
            EXECUTOR_URL,
            json={"prompt": question},
            timeout=120
        )
        response.raise_for_status()

        result = response.json()
        logger.info("Received response from executor")

        return jsonify({
            "answer": result.get("response", "No response"),
            "source": "executor-agent"
        }), 200

    except requests.exceptions.ConnectionError as e:
        logger.error(f"Connection failed to executor: {e}")
        return jsonify({
            "error": "Failed to contact executor",
            "details": "Connection refused - check Consul intentions"
        }), 503

    except requests.exceptions.Timeout:
        logger.error("Request to executor timed out")
        return jsonify({
            "error": "Executor timeout"
        }), 504

    except requests.exceptions.RequestException as e:
        logger.error(f"Request to executor failed: {e}")
        return jsonify({
            "error": "Executor request failed",
            "details": str(e)
        }), 500


@app.route("/", methods=["GET"])
def root():
    """Root endpoint with usage instructions."""
    return jsonify({
        "service": "planner-agent",
        "description": "Entry point for agentic AI questions",
        "endpoints": {
            "/health": "Health check",
            "/ask": "Submit a question (POST with JSON body: {\"question\": \"...\"})"
        },
        "identity": "Authenticated via SPIFFE ID in Consul Connect sidecar"
    }), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    logger.info(f"Starting planner-agent on port {port}")
    logger.info(f"Executor endpoint: {EXECUTOR_URL}")
    app.run(host="0.0.0.0", port=port)
