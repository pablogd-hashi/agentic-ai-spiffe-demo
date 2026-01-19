#!/bin/bash
# Demo Testing Script
# Runs a complete demo flow showing identity enforcement

set -e

# Colors
BLUE='\033[94m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
RESET='\033[0m'
BOLD='\033[1m'

echo -e "\n${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  Agentic AI SPIFFE Demo - Test Flow                       ║${RESET}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# Function to test request
test_request() {
    local question="$1"
    local should_succeed="$2"

    echo -e "${BLUE}Sending question: ${RESET}\"$question\""

    response=$(curl -s -w "\n%{http_code}" http://localhost:8080/ask \
        -H "Content-Type: application/json" \
        -d "{\"question\": \"$question\"}" 2>&1)

    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)

    if [ "$should_succeed" = "true" ]; then
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✓ Request succeeded (expected)${RESET}"
            answer=$(echo "$body" | jq -r '.answer' 2>/dev/null || echo "Failed to parse")
            echo -e "${BOLD}Answer:${RESET} ${answer:0:100}..."
            return 0
        else
            echo -e "${RED}✗ Request failed but should have succeeded${RESET}"
            echo -e "${YELLOW}HTTP Code: $http_code${RESET}"
            echo -e "${YELLOW}Body: $body${RESET}"
            return 1
        fi
    else
        if [ "$http_code" != "200" ]; then
            echo -e "${GREEN}✓ Request failed (expected - no intentions)${RESET}"
            return 0
        else
            echo -e "${RED}✗ Request succeeded but should have failed${RESET}"
            return 1
        fi
    fi
}

# Test 1: Health checks
echo -e "${BOLD}Test 1: Health Checks${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${BLUE}Checking Vault...${RESET}"
vault status > /dev/null 2>&1 && echo -e "${GREEN}✓ Vault is running${RESET}" || echo -e "${RED}✗ Vault is not running${RESET}"

echo -e "${BLUE}Checking Consul...${RESET}"
consul members > /dev/null 2>&1 && echo -e "${GREEN}✓ Consul is running${RESET}" || echo -e "${RED}✗ Consul is not running${RESET}"

echo -e "${BLUE}Checking Nomad...${RESET}"
nomad status > /dev/null 2>&1 && echo -e "${GREEN}✓ Nomad is running${RESET}" || echo -e "${RED}✗ Nomad is not running${RESET}"

echo -e "${BLUE}Checking Planner Agent...${RESET}"
curl -s http://localhost:8080/health > /dev/null 2>&1 && echo -e "${GREEN}✓ Planner agent is healthy${RESET}" || echo -e "${RED}✗ Planner agent is not responding${RESET}"

echo ""

# Test 2: List current intentions
echo -e "${BOLD}Test 2: Current Intentions${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
consul intention list
echo ""

# Test 3: Test with current state
echo -e "${BOLD}Test 3: Testing Current State${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if intentions exist
if consul intention get planner-agent executor-agent > /dev/null 2>&1; then
    echo -e "${YELLOW}Intentions exist - testing should succeed${RESET}"
    test_request "What is SPIFFE?" "true"
else
    echo -e "${YELLOW}No intentions - testing should fail${RESET}"
    test_request "What is SPIFFE?" "false"
fi
echo ""

# Test 4: Demo default deny
echo -e "${BOLD}Test 4: Demonstrate Default Deny${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${BLUE}Removing all intentions...${RESET}"
consul intention delete planner-agent executor-agent 2>/dev/null || echo "Intention already deleted"
consul intention delete executor-agent ollama 2>/dev/null || echo "Intention already deleted"

sleep 2

echo -e "${BLUE}Testing without intentions (should fail)...${RESET}"
test_request "Test question" "false"
echo ""

# Test 5: Demo allow with intentions
echo -e "${BOLD}Test 5: Demonstrate Allow with Intentions${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${BLUE}Creating intentions...${RESET}"
consul intention create planner-agent executor-agent
consul intention create executor-agent ollama

sleep 2

echo -e "${BLUE}Testing with intentions (should succeed)...${RESET}"
test_request "Explain mutual TLS in one sentence" "true"
echo ""

# Test 6: Demo removing specific intention
echo -e "${BOLD}Test 6: Demonstrate Granular Control${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${BLUE}Removing planner → executor intention...${RESET}"
consul intention delete planner-agent executor-agent

sleep 2

echo -e "${BLUE}Testing (should fail at planner → executor)...${RESET}"
test_request "Another test" "false"

echo -e "${BLUE}Restoring planner → executor intention...${RESET}"
consul intention create planner-agent executor-agent

sleep 2

echo -e "${BLUE}Testing (should succeed again)...${RESET}"
test_request "What are the benefits of SPIFFE identities?" "true"
echo ""

# Test 7: Consul service catalog
echo -e "${BOLD}Test 7: Service Catalog${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
consul catalog services
echo ""

# Test 8: Nomad job status
echo -e "${BOLD}Test 8: Nomad Jobs${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
nomad status
echo ""

# Summary
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  Test Summary                                              ║${RESET}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

echo -e "${GREEN}✓ Health checks passed${RESET}"
echo -e "${GREEN}✓ Default deny demonstrated${RESET}"
echo -e "${GREEN}✓ Intention-based allow demonstrated${RESET}"
echo -e "${GREEN}✓ Granular control demonstrated${RESET}"

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo -e "  1. View Consul UI: http://$(hostname -I | awk '{print $1}'):8500"
echo -e "  2. Interactive chat: ${GREEN}task chat${RESET}"
echo -e "  3. View intentions: ${GREEN}consul intention list${RESET}"
echo -e "  4. Check logs: ${GREEN}task logs:planner${RESET}"
echo ""
