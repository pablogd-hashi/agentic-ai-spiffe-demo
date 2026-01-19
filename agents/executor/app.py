"""
Executor Agent

Receives requests from the planner-agent and calls Ollama for inference.

This agent represents privileged access to resources. In this demo, the
resource is Ollama. In production, it could be a database, payment API,
or other sensitive service.

The executor's SPIFFE identity determines what it can access. The planner's
identity determines whether it can call the executor.

The Consul Connect sidecar handles mTLS. The app code sees plain HTTP.
"""

import os
import logging
from flask import Flask, request, jsonify
import requests

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ollama service address
# In Consul Connect, services communicate via localhost to their sidecar
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "localhost")
OLLAMA_PORT = os.getenv("OLLAMA_PORT", "9002")
OLLAMA_URL = f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/generate"

# Ollama model to use
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:0.5b")


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for Consul."""
    return jsonify({"status": "healthy"}), 200


@app.route("/execute", methods=["POST"])
def execute():
    """
    Receive a prompt from the planner and call Ollama for inference.

    Request body:
    {
        "prompt": "What is mutual TLS?"
    }

    Response:
    {
        "response": "...",
        "model": "qwen2.5:0.5b"
    }
    """
    data = request.get_json()

    if not data or "prompt" not in data:
        logger.error("Invalid request: missing 'prompt' field")
        return jsonify({"error": "Missing 'prompt' field"}), 400

    prompt = data["prompt"]
    logger.info(f"Received execution request: {prompt}")

    # Call Ollama for inference
    try:
        logger.info(f"Calling Ollama at {OLLAMA_URL} with model {OLLAMA_MODEL}")

        ollama_payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "stream": False
        }

        response = requests.post(
            OLLAMA_URL,
            json=ollama_payload,
            timeout=120
        )
        response.raise_for_status()

        result = response.json()
        ollama_response = result.get("response", "No response from Ollama")

        logger.info(f"Ollama response received (length: {len(ollama_response)})")

        return jsonify({
            "response": ollama_response,
            "model": OLLAMA_MODEL
        }), 200

    except requests.exceptions.ConnectionError as e:
        logger.error(f"Connection failed to Ollama: {e}")
        return jsonify({
            "error": "Failed to contact Ollama",
            "details": "Connection refused - check Consul intentions and Ollama service"
        }), 503

    except requests.exceptions.Timeout:
        logger.error("Request to Ollama timed out")
        return jsonify({
            "error": "Ollama timeout"
        }), 504

    except requests.exceptions.RequestException as e:
        logger.error(f"Request to Ollama failed: {e}")
        return jsonify({
            "error": "Ollama request failed",
            "details": str(e)
        }), 500


@app.route("/", methods=["GET"])
def root():
    """Root endpoint with usage instructions."""
    return jsonify({
        "service": "executor-agent",
        "description": "Executes prompts via Ollama",
        "endpoints": {
            "/health": "Health check",
            "/execute": "Execute a prompt (POST with JSON body: {\"prompt\": \"...\"})"
        },
        "ollama_model": OLLAMA_MODEL,
        "identity": "Authenticated via SPIFFE ID in Consul Connect sidecar"
    }), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8081"))
    logger.info(f"Starting executor-agent on port {port}")
    logger.info(f"Ollama endpoint: {OLLAMA_URL}")
    logger.info(f"Ollama model: {OLLAMA_MODEL}")
    app.run(host="0.0.0.0", port=port)
