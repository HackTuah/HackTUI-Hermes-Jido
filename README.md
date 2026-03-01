# HackTUI 

    ██╗  ██╗ █████╗  ██████╗██╗  ██╗ ████████╗██╗   ██╗██╗
    ██║  ██║██╔══██╗██╔════╝██║ ██╔╝ ╚══██╔══╝██║   ██║██║
    ███████║███████║██║     █████╔╝     ██║   ██║   ██║██║
    ██╔══██║██╔══██║██║     ██╔═██╗     ██║   ██║   ██║██║
    ██║  ██║██║  ██║╚██████╗██║  ██╗    ██║   ╚██████╔╝██║
    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═╝    ╚═════╝ ╚═╝

------------------------------------------------------------------------

##  Project Overview

HackTUI is a **Stateful Network Detection & Response (NDR)** platform
built on the Elixir/OTP runtime.\
It transforms raw system telemetry into actionable security intelligence
using a modular, fault-tolerant architecture designed for
high-throughput environments.

------------------------------------------------------------------------

##  Dashboard Preview

![HackTUI Security Interface](assets/images/UI.png)

*Figure 1: Real-time correlation of DNS beaconing events and GeoIP
enrichment.*

------------------------------------------------------------------------

##  Advanced SIEM Features

-   **Stateful Correlation Engine**\
    Tracks behavioral patterns over time. Automatically escalates
    repetitive suspicious lookups from standard warnings to **CRITICAL**
    alerts.

-   **Asynchronous Threat Enrichment**\
    Dedicated enrichment worker performing non-blocking DNS resolution
    and GeoIP lookups (Country, ISP) for flagged domains.

-   **Persistent Historical Storage**\
    Integrated with **PostgreSQL** via Ecto. All security events are
    serialized to a permanent data store for forensic analysis and
    historical reporting.

-   **Fault-Tolerant Design**\
    Built on the Erlang/OTP supervision tree. Failures in one component
    do not compromise the entire SOC.

------------------------------------------------------------------------

##  Architecture

The system operates as a supervised tree of specialized concurrent
processes:

-   **NetScout** -- Ingestion layer managing raw packet capture via
    `tcpdump`.
-   **Enricher** -- Intelligence layer providing GeoIP and Threat Intel
    metadata.
-   **Repo** -- Persistence layer managing the PostgreSQL interface.
-   **State** -- Correlation engine and single source of truth.
-   **Dashboard** -- Terminal rendering engine built on `ExRatatui`.

------------------------------------------------------------------------

##  Installation & Setup

### 1️⃣ System Dependencies

Monitoring agents require specific Linux capabilities:

``` bash
# Grant network sniffing permissions
sudo setcap 'cap_net_raw,cap_net_admin=eip' $(which tcpdump)
```

``` bash
# Grant journal access
sudo usermod -a -G systemd-journal $USER
```

Log out and back in after modifying group permissions.

------------------------------------------------------------------------

### 2️⃣ Environment Configuration

Create a `.env` file in the project root:

``` bash
# .env
export HACKTUI_DB_PASS="your_secure_30_character_password"
```

------------------------------------------------------------------------

### 3️⃣ Database Initialization

``` bash
source .env
mix deps.get
mix ecto.setup
```

------------------------------------------------------------------------

## ▶ Usage

``` bash
source .env
mix run --no-halt
```

------------------------------------------------------------------------

## 🎛️ Controls

  Key   Action
  ----- ---------------------------------------
  Q     Graceful Shutdown
  C     Clear In-Memory Alerts
  H     Fetch Historical Alerts from Database

------------------------------------------------------------------------

##  Tech Stack

-   **Language:** Elixir 1.19+ (OTP 28)
-   **Database:** PostgreSQL 16+ (Ecto)
-   **Networking:** Req (HTTP), Port-based TCPDump
-   **TUI:** ExRatatui 0.4.1

------------------------------------------------------------------------

##  License

MIT License
