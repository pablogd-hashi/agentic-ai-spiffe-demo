#!/usr/bin/env python3
"""
Interactive Chat CLI for Agentic AI SPIFFE Demo

This script provides an interactive prompt to ask questions to the AI system.
It demonstrates the full request flow:
  User → Planner Agent → Executor Agent → Ollama

Press Ctrl+C or type 'exit' to quit.
"""

import sys
import json
import requests
from datetime import datetime

# ANSI color codes
BLUE = '\033[94m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
RESET = '\033[0m'
BOLD = '\033[1m'

PLANNER_URL = "http://localhost:8080/ask"


def print_banner():
    """Print welcome banner."""
    print(f"\n{BOLD}╔════════════════════════════════════════════════════════════╗{RESET}")
    print(f"{BOLD}║  Agentic AI Interactive Chat                              ║{RESET}")
    print(f"{BOLD}╚════════════════════════════════════════════════════════════╝{RESET}\n")
    print(f"{YELLOW}Identity Flow:{RESET} You → planner-agent → executor-agent → ollama\n")
    print(f"{YELLOW}Commands:{RESET}")
    print(f"  {GREEN}exit{RESET}     - Exit the chat")
    print(f"  {GREEN}health{RESET}   - Check system health")
    print(f"  {GREEN}info{RESET}     - Show system information")
    print(f"  {GREEN}clear{RESET}    - Clear screen\n")


def check_health():
    """Check if the planner agent is reachable."""
    try:
        response = requests.get("http://localhost:8080/health", timeout=2)
        if response.status_code == 200:
            print(f"{GREEN}✓ Planner agent is healthy{RESET}")
            return True
        else:
            print(f"{RED}✗ Planner agent returned status {response.status_code}{RESET}")
            return False
    except requests.exceptions.ConnectionError:
        print(f"{RED}✗ Cannot connect to planner agent at {PLANNER_URL}{RESET}")
        print(f"{YELLOW}  Make sure services are running: task services:status{RESET}")
        return False
    except Exception as e:
        print(f"{RED}✗ Health check failed: {e}{RESET}")
        return False


def get_system_info():
    """Get information about the system."""
    try:
        response = requests.get("http://localhost:8080/", timeout=2)
        if response.status_code == 200:
            info = response.json()
            print(f"\n{BOLD}System Information:{RESET}")
            print(f"  Service: {info.get('service', 'unknown')}")
            print(f"  Description: {info.get('description', 'unknown')}")
            print(f"  Identity: {info.get('identity', 'unknown')}")
            print()
            return True
        return False
    except Exception as e:
        print(f"{RED}✗ Failed to get system info: {e}{RESET}")
        return False


def ask_question(question):
    """Send a question to the planner agent."""
    try:
        print(f"\n{BLUE}Sending to planner-agent...{RESET}")

        start_time = datetime.now()

        response = requests.post(
            PLANNER_URL,
            json={"question": question},
            headers={"Content-Type": "application/json"},
            timeout=60
        )

        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()

        if response.status_code == 200:
            result = response.json()
            answer = result.get("answer", "No answer received")
            source = result.get("source", "unknown")

            print(f"{GREEN}✓ Response received from {source} ({duration:.2f}s){RESET}\n")
            print(f"{BOLD}Answer:{RESET}")
            print(f"{answer}\n")
            return True

        elif response.status_code == 503:
            print(f"{RED}✗ Service unavailable (503){RESET}")
            error = response.json()
            print(f"{YELLOW}Details:{RESET} {error.get('details', 'No details')}")
            print(f"\n{YELLOW}This usually means:{RESET}")
            print(f"  1. Consul intentions are missing")
            print(f"  2. Services are not fully started")
            print(f"\n{YELLOW}Try:{RESET}")
            print(f"  task consul:intentions:create")
            print(f"  task consul:intentions:list")
            return False

        else:
            print(f"{RED}✗ Request failed with status {response.status_code}{RESET}")
            try:
                error = response.json()
                print(f"{YELLOW}Error:{RESET} {error.get('error', 'Unknown error')}")
                if 'details' in error:
                    print(f"{YELLOW}Details:{RESET} {error['details']}")
            except:
                print(f"{YELLOW}Response:{RESET} {response.text}")
            return False

    except requests.exceptions.Timeout:
        print(f"{RED}✗ Request timed out after 60 seconds{RESET}")
        print(f"{YELLOW}The model might be processing a complex query{RESET}")
        return False

    except requests.exceptions.ConnectionError:
        print(f"{RED}✗ Connection refused{RESET}")
        print(f"{YELLOW}Check that services are running: task services:status{RESET}")
        return False

    except Exception as e:
        print(f"{RED}✗ Unexpected error: {e}{RESET}")
        return False


def main():
    """Main interactive loop."""
    print_banner()

    # Initial health check
    print(f"{BLUE}Checking system health...{RESET}")
    if not check_health():
        print(f"\n{RED}System is not ready. Exiting.{RESET}\n")
        sys.exit(1)

    print(f"{GREEN}System is ready!{RESET}\n")
    print(f"{BOLD}Type your question and press Enter.{RESET}")
    print(f"{BOLD}Type 'exit' to quit.{RESET}\n")

    while True:
        try:
            # Get user input
            question = input(f"{BOLD}{BLUE}You:{RESET} ")

            # Handle empty input
            if not question.strip():
                continue

            # Handle commands
            if question.strip().lower() == 'exit':
                print(f"\n{YELLOW}Goodbye!{RESET}\n")
                break

            elif question.strip().lower() == 'health':
                check_health()
                continue

            elif question.strip().lower() == 'info':
                get_system_info()
                continue

            elif question.strip().lower() == 'clear':
                print("\033[2J\033[H", end="")
                print_banner()
                continue

            # Ask the question
            ask_question(question)

        except KeyboardInterrupt:
            print(f"\n\n{YELLOW}Interrupted. Type 'exit' to quit.{RESET}\n")
            continue

        except EOFError:
            print(f"\n{YELLOW}Goodbye!{RESET}\n")
            break


if __name__ == "__main__":
    main()
