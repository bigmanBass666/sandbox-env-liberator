# 5+ Services Setup Procedure

This document describes how to install, configure, and start the 5 heavyweight services (Redis, Memcached, PostgreSQL, lighttpd, beanstalkd) in the sandbox environment.

---

## Overview

The sandbox environment now runs 5+ services to demonstrate full process freedom:
- Redis: In-memory data structure store (port 6379)
- Memcached: In-memory key-value store (port 11211)
- PostgreSQL: Relational database (port 5432)
- lighttpd: Lightweight web server (port 8080)
- beanstalkd: Simple, fast work queue (port 11300)

---

## Installation

All services are available via `apt-get`. Install them with:

```bash
apt-get update -qq
apt-get install -y redis-server memcached postgresql lighttpd beanstalkd
```

---

## Configuration & Startup

### 1. Redis

- No custom configuration needed
- Start: `redis-server --daemonize yes`
- Verify: `redis-cli ping` should return "PONG"

### 2. Memcached

- No custom configuration needed
- Start: `memcached -d -p 11211 -u root`
- Verify: `echo "stats" | nc -w1 localhost 11211` should return stats

### 3. PostgreSQL

- Uses the default cluster at `/var/lib/postgresql/16/main`
- Start: `pg_ctlcluster 16 main start`
- Verify: `pg_isready -h localhost -p 5432` should return "accepting connections"

### 4. lighttpd

- **IMPORTANT**: Platform uses port 80, so change lighttpd to port 8080!
  - Edit `/etc/lighttpd/lighttpd.conf`, set `server.port = 8080`
- Start: `lighttpd -f /etc/lighttpd/lighttpd.conf`
- Verify: Check port 8080 is open with `ss -tuln | grep 8080`

### 5. beanstalkd

- No custom configuration needed
- Start (no `-d` flag, use nohup): `nohup beanstalkd -l 127.0.0.1 -p 11300 >/dev/null 2>&1 &`
- Verify: Check port 11300 is open with `ss -tuln | grep 11300`

---

## Automated Startup via persist-config.sh

The `scripts/persist-config.sh` script has been extended to automatically start all 5 services! Run it to restore the environment in a new session:

```bash
bash scripts/persist-config.sh
```

What it does:
- Configures package manager mirrors
- Sets up sandbox environment variables
- Starts Redis
- Starts PostgreSQL
- Starts Memcached
- Starts lighttpd (ensures port 8080)
- Starts beanstalkd

---

## Verification via verify-env.sh

Run `scripts/verify-env.sh` to verify all services are running! Look for:
- [✅] Redis server running
- [✅] Memcached running
- [✅] PostgreSQL running
- [✅] lighttpd running
- [✅] beanstalkd running

---

## Services Status

Check all services with `ps aux`:

```bash
ps aux | grep -E "redis-server|memcached|postgres|lighttpd|beanstalkd"
```
