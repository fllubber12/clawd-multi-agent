#!/usr/bin/env python3
"""
Sentry Webhook Handler - Receives Sentry alerts and forwards to Molty gateway.

Listens on port 18790 for POST requests from Sentry webhooks.
Parses error context and dispatches to clawdbot for triage/auto-fix.

Usage:
    python scripts/sentry-webhook-handler.py

Environment:
    WEBHOOK_PORT - Port to listen on (default: 18790)
    CLAWD_HOME - Clawd directory (default: ~/clawd)
"""

import json
import os
import subprocess
import sys
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs

# Configuration
WEBHOOK_PORT = int(os.environ.get("WEBHOOK_PORT", 18790))
CLAWD_HOME = Path(os.environ.get("CLAWD_HOME", Path.home() / "clawd"))
LOG_DIR = CLAWD_HOME / "logs" / "sentry-webhooks"

# Project mapping (Sentry project slug → local path)
PROJECT_PATHS = {
    "polymarket-copytrader": "~/Projects/Polymarket_CopyTrader",
    "polymarket": "~/Projects/Polymarket_CopyTrader",
    "ygo-combo-pipeline": "~/Desktop/testing",
    "ygo": "~/Desktop/testing",
    "budget-pipeline": "~/Desktop/budget",
    "budget": "~/Desktop/budget",
    "kalshi-arbitrage": "~/Projects/Kalshi_Arbitrage",
    "kalshi": "~/Projects/Kalshi_Arbitrage",
    "clawd": "~/clawd",
}


def extract_error_context(payload: dict) -> dict:
    """Extract relevant error context from Sentry webhook payload."""
    context = {
        "timestamp": datetime.now().isoformat(),
        "project": None,
        "error_type": None,
        "error_message": None,
        "file": None,
        "line": None,
        "function": None,
        "stack_trace": None,
        "culprit": None,
        "level": None,
        "url": None,
    }

    # Handle different Sentry webhook formats
    data = payload.get("data", payload)
    event = data.get("event", data)

    # Project info
    context["project"] = (
        payload.get("project_slug") or
        payload.get("project", {}).get("slug") or
        data.get("project", {}).get("slug") or
        "unknown"
    )

    # Error info
    context["level"] = event.get("level", "error")
    context["culprit"] = event.get("culprit", "")
    context["url"] = payload.get("url", event.get("web_url", ""))

    # Exception details
    exception = event.get("exception", {})
    values = exception.get("values", [])

    if values:
        exc = values[0]  # Primary exception
        context["error_type"] = exc.get("type", "Error")
        context["error_message"] = exc.get("value", "Unknown error")

        # Stack trace
        stacktrace = exc.get("stacktrace", {})
        frames = stacktrace.get("frames", [])

        if frames:
            # Get the most relevant frame (usually the last one in app code)
            for frame in reversed(frames):
                if frame.get("in_app", True):
                    context["file"] = frame.get("filename", "")
                    context["line"] = frame.get("lineno")
                    context["function"] = frame.get("function", "")
                    break

            # Format stack trace summary
            trace_lines = []
            for frame in frames[-5:]:  # Last 5 frames
                filename = frame.get("filename", "?")
                lineno = frame.get("lineno", "?")
                func = frame.get("function", "?")
                trace_lines.append(f"  {filename}:{lineno} in {func}")
            context["stack_trace"] = "\n".join(trace_lines)

    # Fallback for message-only events
    if not context["error_message"]:
        context["error_message"] = event.get("message", event.get("title", "Unknown"))
        context["error_type"] = "Message"

    return context


def format_molty_message(context: dict) -> str:
    """Format error context for Molty notification."""
    project = context["project"]
    error_type = context["error_type"] or "Error"
    error_msg = context["error_message"] or "Unknown error"
    file_info = ""

    if context["file"]:
        file_info = f" in {context['file']}"
        if context["line"]:
            file_info += f":{context['line']}"

    # Truncate long messages
    if len(error_msg) > 100:
        error_msg = error_msg[:97] + "..."

    return f"🚨 Sentry: {error_type}: {error_msg}{file_info} [{project}]"


def format_triage_context(context: dict) -> str:
    """Format detailed context for auto-fix triage."""
    lines = [
        f"Project: {context['project']}",
        f"Error: {context['error_type']}: {context['error_message']}",
    ]

    if context["file"]:
        lines.append(f"Location: {context['file']}:{context['line']} in {context['function']}")

    if context["stack_trace"]:
        lines.append(f"Stack trace:\n{context['stack_trace']}")

    if context["url"]:
        lines.append(f"Sentry URL: {context['url']}")

    # Add project path
    project_path = PROJECT_PATHS.get(context["project"], "unknown")
    lines.append(f"Repo path: {project_path}")

    return "\n".join(lines)


def notify_molty(message: str, context: dict):
    """Send notification to Molty gateway."""
    try:
        # Write detailed context to file for potential auto-fix
        context_file = LOG_DIR / f"context_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        context_file.parent.mkdir(parents=True, exist_ok=True)
        with open(context_file, "w") as f:
            json.dump(context, f, indent=2)

        # Send notification via clawdbot agent
        # Uses the default agent/session to deliver Sentry alerts
        cmd = [
            "clawdbot", "agent",
            "--message", message,
            "--deliver"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            print(f"[OK] Notified Molty: {message}")
        else:
            print(f"[WARN] Molty notification failed: {result.stderr}")

    except FileNotFoundError:
        print("[WARN] clawdbot not found - skipping Molty notification")
    except subprocess.TimeoutExpired:
        print("[WARN] Molty notification timed out")
    except Exception as e:
        print(f"[ERROR] Failed to notify Molty: {e}")


def log_webhook(context: dict, raw_payload: dict):
    """Log webhook for debugging and audit."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = LOG_DIR / f"webhook_{timestamp}.json"

    log_entry = {
        "received_at": context["timestamp"],
        "context": context,
        "raw_payload": raw_payload,
    }

    with open(log_file, "w") as f:
        json.dump(log_entry, f, indent=2)

    print(f"[LOG] Saved to {log_file}")


class SentryWebhookHandler(BaseHTTPRequestHandler):
    """HTTP handler for Sentry webhooks."""

    def do_POST(self):
        """Handle POST requests from Sentry."""
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)

            # Parse JSON payload
            try:
                payload = json.loads(body.decode("utf-8"))
            except json.JSONDecodeError:
                # Try form-encoded
                payload = {"raw": body.decode("utf-8")}

            print(f"\n[WEBHOOK] Received from Sentry")

            # Extract error context
            context = extract_error_context(payload)

            # Log the webhook
            log_webhook(context, payload)

            # Format and send notification
            message = format_molty_message(context)
            notify_molty(message, context)

            # Also print triage context
            triage = format_triage_context(context)
            print(f"\n[TRIAGE CONTEXT]\n{triage}\n")

            # Send success response
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())

        except Exception as e:
            print(f"[ERROR] Webhook processing failed: {e}")
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_GET(self):
        """Health check endpoint."""
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({
            "status": "ok",
            "service": "sentry-webhook-handler",
            "port": WEBHOOK_PORT,
        }).encode())

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass


def main():
    """Start the webhook server."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    server = HTTPServer(("0.0.0.0", WEBHOOK_PORT), SentryWebhookHandler)
    print(f"🚀 Sentry webhook handler listening on port {WEBHOOK_PORT}")
    print(f"   Health check: http://localhost:{WEBHOOK_PORT}/")
    print(f"   Logs: {LOG_DIR}")
    print(f"   Press Ctrl+C to stop\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Shutting down webhook handler")
        server.shutdown()


if __name__ == "__main__":
    main()
