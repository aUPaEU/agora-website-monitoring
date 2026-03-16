# agora-web-monitoring

Performance monitoring for Agora websites using [sitespeed.io](https://www.sitespeed.io/), Graphite and Grafana.

## How it works

The stack runs **Graphite** (metrics storage) and **Grafana** (dashboards) via the official sitespeed.io Docker Compose. A script reads a list of URLs and launches a sitespeed.io container for each one, sending results to Graphite. Grafana reads from Graphite and displays the dashboards.

```
urls.txt → run-sitespeed.sh → sitespeed.io container → Graphite → Grafana
```

Each test run produces metrics for every combination of:

| Dimension    | Values                          |
|--------------|---------------------------------|
| Device       | desktop, mobile                 |
| Browser      | chrome, firefox                 |
| Connectivity | native, cable, 3gfast, 3g, 2g   |

In Grafana these appear as the `testname`, `browser` and `connectivity` dropdown filters.

---

## Files

| File               | Purpose                                                |
|--------------------|--------------------------------------------------------|
| `run-sitespeed.sh` | Main script — runs tests for all URLs and combinations |
| `urls.txt`         | List of URLs to monitor (one per line)                 |
| `.env.example`     | Configuration template — copy to `.env` and edit       |
| `cron`             | Cron job definitions                                   |
| `init.sh`          | Sets up `.env` and installs cron jobs (Linux / macOS)  |

---

## Configuration

Copy `.env.example` to `.env` and adjust the values:

```bash
cp .env.example .env
```

| Variable         | Description                                      | Default          |
|------------------|--------------------------------------------------|------------------|
| `DOCKER_NETWORK` | Docker network of the sitespeed.io compose stack | `docker_default` |
| `GRAPHITE_HOST`  | Graphite hostname or IP                          | `graphite`       |
| `GRAPHITE_PORT`  | Graphite plaintext port                          | `2003`           |
| `ITERATIONS`     | Browser iterations per URL (accuracy vs speed)   | `3`              |

> **Windows:** `GRAPHITE_HOST` must be set to the Graphite container IP (e.g. `172.26.0.2`).
> Find it with `docker network inspect docker_default` and look for `docker-graphite-1`.
>
> **Linux / macOS:** leave `GRAPHITE_HOST=graphite` — Docker resolves container hostnames automatically.

---

## Local setup

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- Git

### 1. Clone and start the official sitespeed.io stack

**Windows (PowerShell)**
```powershell
git clone --depth 1 --filter=blob:none --sparse https://github.com/sitespeedio/sitespeed.io.git
cd sitespeed.io
git sparse-checkout set docker
cd docker
docker compose up -d
```

**Linux / macOS**
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/sitespeedio/sitespeed.io.git
cd sitespeed.io
git sparse-checkout set docker
cd docker
docker compose up -d
```

Grafana → `http://localhost:3000`
Default credentials are in the `docker-compose.yml` file.

### 2. Configure .env

**Windows (PowerShell)**
```powershell
Copy-Item .env.example .env
# Edit .env and set GRAPHITE_HOST to the container IP
notepad .env
```

**Linux / macOS**
```bash
cp .env.example .env
# Default values work as-is on Linux/macOS
```

### 3. Edit urls.txt

Add the URLs you want to monitor, one per line. Lines starting with `#` are ignored.

### 4. Run a quick test

**Windows (PowerShell → WSL)**

Docker Desktop on Windows requires running the script inside WSL:
```powershell
wsl
```
Then inside WSL:
```bash
cd /mnt/c/path/to/agora-web-monitoring

# Fix Windows line endings (only needed once)
sed -i 's/\r//' run-sitespeed.sh urls.txt .env

# Quick mode: desktop + chrome + native only
bash run-sitespeed.sh ./urls.txt quick
```

**Linux / macOS**
```bash
cd /path/to/agora-web-monitoring
bash run-sitespeed.sh ./urls.txt quick
```

### 5. Check results in Grafana

Open `http://localhost:3000` → sitespeed.io folder → **Page Summary** dashboard.
Use the dropdowns to filter by domain, browser and connectivity.

---

## Production setup (Linux VPS)

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Clone and start the official sitespeed.io stack

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/sitespeedio/sitespeed.io.git
cd sitespeed.io
git sparse-checkout set docker
docker compose up -d
```

### 3. Clone this repository

```bash
git clone https://github.com/your-org/agora-web-monitoring.git /opt/agora-web-monitoring
cd /opt/agora-web-monitoring
```

### 4. Set up and install cron jobs

```bash
bash init.sh
```

`init.sh` will:
1. Create `.env` from `.env.example` if it doesn't exist yet
2. Install the cron jobs from the `cron` file

Two cron jobs are installed:
- **3:00 AM daily** — full cycle (all device / browser / connectivity combinations)
- **Every hour** — quick cycle (desktop + chrome + native only)

### 5. Check logs

```bash
tail -f /var/log/sitespeed.log
```

---

## Debugging

Filter output to show only errors and results:

**Linux / macOS / WSL**
```bash
bash run-sitespeed.sh ./urls.txt 2>&1 | grep -E "\[OK\]|\[FAIL\]|\[ERROR\]|Couldn't|invalid"
```

**Windows (PowerShell)**
```powershell
wsl bash run-sitespeed.sh ./urls.txt 2>&1 | Select-String "\[OK\]|\[FAIL\]|\[ERROR\]|Couldn't|invalid"
```