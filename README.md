# HackTUI

HackTUI is a terminal‑native purple team security operations platform
built on Elixir and the BEAM runtime.

It combines real‑time telemetry ingestion, alert and investigation
lifecycle management, terminal SOC operations, bounded agent assistance
using Jido, and AI interoperability via MCP (Model Context Protocol).

HackTUI is designed as a research platform for autonomous and
human‑guided security operations.

The repository includes the HackTUI platform itself, the MCP server
implementation, and Jido‑based bounded agent components. My external
Hermes agent used during development is not included in this repository.

------------------------------------------------------------------------

# Architecture

HackTUI is an Elixir umbrella application.

apps/ hacktui_agent hacktui_collab hacktui_core hacktui_hub
hacktui_sensor hacktui_store hacktui_tui

hacktui_core Domain logic including commands, events, aggregates, alert
lifecycle, and investigation lifecycle.

hacktui_store Persistence layer for alerts, cases, observations,
approvals, and audit data.

hacktui_hub Runtime coordination, alert promotion, telemetry
aggregation, health checks, and privacy masking.

hacktui_sensor Telemetry ingestion including journald events, network
telemetry, and BEAM process signals.

hacktui_tui Terminal user interface for SOC operations.

hacktui_agent Agent‑assisted investigation workflows powered by the Jido
runtime.

hacktui_collab Experimental boundary for external integrations.

------------------------------------------------------------------------

# Core Capabilities

Realtime host telemetry ingestion Network flow ingestion via tshark
Security event ingestion from journald Process and BEAM runtime
telemetry Alert lifecycle management Investigation case lifecycle
Terminal SOC dashboard Agent‑assisted investigation workflows MCP server
for AI interoperability Jido runtime integration

------------------------------------------------------------------------

# Requirements

Recommended

Elixir 1.19+ Erlang OTP 28+ PostgreSQL 14+ tshark dumpcap

Optional

journalctl observer GUI support

Linux environments are recommended.

------------------------------------------------------------------------

# Installation

Clone the repository

git clone `<REPO_URL>`{=html} cd hacktui_hermes

Install dependencies

mix deps.get

Compile

mix compile

------------------------------------------------------------------------

# Database Setup

Start PostgreSQL

sudo systemctl start postgresql

Create database

sudo -u postgres psql

CREATE USER hacktui WITH PASSWORD 'hacktui'; CREATE DATABASE hacktui_dev
OWNER hacktui;

Environment variables

export HACKTUI_START_REPO=true export HACKTUI_DB_NAME=hacktui_dev export
HACKTUI_DB_USER=hacktui export HACKTUI_DB_PASS=hacktui export
HACKTUI_DB_HOST=localhost export HACKTUI_DB_PORT=5432

Run migrations

mix ecto.create mix ecto.migrate

------------------------------------------------------------------------

# Running HackTUI

iex -S mix

Application.ensure_all_started(:hacktui_store)
Application.ensure_all_started(:hacktui_hub)
Application.ensure_all_started(:hacktui_sensor)
Application.ensure_all_started(:hacktui_agent)
Application.ensure_all_started(:hacktui_tui)

Check health

HacktuiHub.Health.status() HacktuiAgent.Health.status()

------------------------------------------------------------------------

# Launching the Terminal SOC

mix hacktui.tui

The dashboard displays

alert queue case board recent observations system health

------------------------------------------------------------------------

# Observer GUI

iex -S mix

:observer.start()

If necessary

:wx.new() :observer.start()

------------------------------------------------------------------------

# Jido Verification

Code.ensure_loaded?(Jido) Code.ensure_loaded?(Jido.Agent)
Code.ensure_loaded?(Jido.Action)

Application.ensure_all_started(:jido) Application.spec(:jido)

:code.which(Jido) :code.which(Jido.Agent) :code.which(Jido.Action)

------------------------------------------------------------------------

# MCP Server

Run MCP server

HACKTUI_MCP_STDIO=1 ./bin/hacktui-mcp

Initialization test

body='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-05","capabilities":{},"clientInfo":{"name":"demo","version":"0.1"}}}'

printf 'Content-Length: %s`\r\n`{=tex}`\r\n`{=tex}%s'
"$(printf '%s' "$body" \| wc -c)" "\$body" \| HACKTUI_MCP_STDIO=1
./bin/hacktui-mcp

------------------------------------------------------------------------

# Telemetry Testing

HacktuiHub.QueryService.clear_buffer()

Generate traffic

ping -c 2 8.8.8.8 curl https://google.com

Inspect observations

HacktuiHub.QueryService.latest_observations()

------------------------------------------------------------------------

# Alert Workflow Demo

alias HacktuiCore.Commands.CreateAlert

HacktuiHub.Runtime.create_alert( %CreateAlert{ alert_id: "demo-" \<\>
Integer.to_string(System.unique_integer(\[:positive\])), title: "Beacon
Detection", severity: :high, observation_refs: \["manual-net-1"\],
actor: "demo" }, repo: HacktuiStore.Repo, occurred_at:
DateTime.utc_now(), event_id: "evt-" \<\>
Integer.to_string(System.unique_integer(\[:positive\])) )

Check alerts

HacktuiHub.QueryService.alert_queue(HacktuiStore.Repo)

Check cases

HacktuiHub.QueryService.case_board(HacktuiStore.Repo)

------------------------------------------------------------------------

# Clearing Demo State

HacktuiStore.Repo.delete_all(HacktuiStore.Schema.CaseRecord)
HacktuiStore.Repo.delete_all(HacktuiStore.Schema.Alert)
HacktuiStore.Repo.delete_all(HacktuiStore.Schema.Observation)

HacktuiHub.QueryService.clear_buffer()

------------------------------------------------------------------------

# Running Tests

mix test

mix test apps/hacktui_core/test mix test apps/hacktui_hub/test mix test
apps/hacktui_agent/test

mix test --trace

------------------------------------------------------------------------

# Project Status

HackTUI is a research prototype exploring terminal SOC operations,
purple team telemetry analysis, and agent assisted investigation.

It is not production ready.
