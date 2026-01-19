# Agent Dockerfile
#
# This Dockerfile builds both planner-agent and executor-agent.
# The specific agent is determined by the AGENT_TYPE build argument.
#
# Build examples:
#   docker build --build-arg AGENT_TYPE=planner -t planner-agent:latest .
#   docker build --build-arg AGENT_TYPE=executor -t executor-agent:latest .

FROM python:3.11-slim

ARG AGENT_TYPE
RUN test -n "$AGENT_TYPE" || (echo "AGENT_TYPE build argument is required" && false)

# Install curl for healthchecks
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install dependencies
COPY ${AGENT_TYPE}/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY ${AGENT_TYPE}/app.py .

# Expose port
# Planner runs on 8080, executor on 8081 (configurable via PORT env var)
EXPOSE 8080

# Run the application
CMD ["python", "app.py"]
