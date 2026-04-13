# Tomcat + ORDS Docker Image

Docker image combining Apache Tomcat 9 with Oracle REST Data Services (ORDS) 25.4, ready for deployment against an Oracle Database. APEX static images are served from an external volume mount.

[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Architecture

```
┌──────────────────────────────────────────────────┐
│  tomcat-ords container                           │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Apache Tomcat 9.0  (JDK 17 Temurin)      │  │
│  │                                            │  │
│  │  /ords  ─── ords.war (ORDS 25.4)          │  │
│  │  /i     ─── symlink → /opt/oracle/apex/    │  │
│  │              images (APEX static files)     │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Ports: 8080 (HTTP) / 8443 (HTTPS, optional)    │
│                                                  │
│  /opt/oracle/ords/bin/ords   ─── ORDS CLI        │
│  /opt/oracle/sqlcl/bin/sql   ─── SQLcl           │
│                                                  │
│  Volumes:                                        │
│    /etc/ords/config     ─── ORDS configuration   │
│    /opt/oracle/apex     ─── APEX images          │
│    /export              ─── Export/scratch space  │
│    /ords-entrypoint.d   ─── Custom init scripts  │
│                                                  │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
          Oracle Database
          (host:port/service)
```

The image is built using a multi-stage Dockerfile:

1. **Stage 1** extracts `ords.war`, the ORDS CLI, and SQLcl from a locally-pulled Oracle ORDS container image
2. **Stage 2** builds the final image on `tomcat:9-jdk17-temurin`, deploys the WAR, and symlinks APEX images from a volume mount

Tomcat 9 is used because ORDS 25.4 depends on `javax.servlet` (Tomcat 10+ uses the incompatible `jakarta.servlet` namespace).

## Prerequisites

- **Docker** (17.1+) or **Podman** (1.6.0+)
- **Oracle ORDS image pulled locally** — requires one-time Oracle T&C acceptance:
  ```bash
  # 1. Accept terms at https://container-registry.oracle.com/ords/ocr/ba/database/ords
  # 2. Login and pull
  docker login container-registry.oracle.com
  docker pull container-registry.oracle.com/database/ords:latest
  ```
- **APEX images extracted** on the host (downloaded from [Oracle APEX Downloads](https://www.oracle.com/tools/downloads/apex-downloads/)):
  ```bash
  mkdir -p /tmp/docker/containers/ords/apex
  cd /tmp && unzip apex-latest.zip "apex/images/*"
  mv /tmp/apex/images /tmp/docker/containers/ords/apex/images
  rm -rf /tmp/apex
  ```

## Build

Using the build script:

```bash
./buildContainerImage.sh
```

Or directly with Docker:

```bash
docker build -t tomcat-ords:latest .
```

Build script options:

| Flag | Description |
|------|-------------|
| `-t tag` | Image tag (default: `latest`) |
| `-n name` | Image name (default: `tomcat-ords`) |
| `-s image` | Source ORDS image (default: `container-registry.oracle.com/database/ords:latest`) |
| `-o opts` | Additional Docker build options |

Build arguments:

| Arg | Default | Description |
|-----|---------|-------------|
| `ORDS_IMAGE` | `container-registry.oracle.com/database/ords:latest` | Source ORDS image (must exist locally) |
| `TLS_KEYSTORE_PASS` | `changeit` | Keystore password (used when TLS is enabled at runtime) |

## Run

### With Docker Compose (recommended)

```bash
cp .env.example .env    # edit with your values
docker compose up -d    # build + run
docker compose logs -f  # watch startup
```

### Basic docker run (HTTP only)

```bash
docker run -p 8080:8080 \
  -v /tmp/docker/containers/ords/ords_config:/etc/ords/config \
  -v /tmp/docker/containers/ords/apex:/opt/oracle/apex \
  -v /tmp/docker/export:/export \
  -v /etc/timezone:/etc/timezone:ro \
  -e ORACLE_HOST=mydbhost \
  -e ORACLE_PWD=mysyspassword \
  tomcat-ords:latest
```

### With TLS enabled

```bash
docker run -p 8080:8080 -p 8443:8443 \
  -v /tmp/docker/containers/ords/ords_config:/etc/ords/config \
  -v /tmp/docker/containers/ords/apex:/opt/oracle/apex \
  -v /tmp/docker/export:/export \
  -v /etc/timezone:/etc/timezone:ro \
  -v ./tls/keystore.p12:/usr/local/tomcat/conf/tls/keystore.p12:ro \
  -e ORACLE_HOST=mydbhost \
  -e ORACLE_PWD=mysyspassword \
  -e ENABLE_TLS=true \
  -e TLS_KEYSTORE_PASS=changeit \
  tomcat-ords:latest
```

Access ORDS at:
- HTTP: `http://localhost:8080/ords/`
- HTTPS: `https://localhost:8443/ords/` (when TLS enabled)

## Environment Variables

### Database Connection

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ORACLE_HOST` | No | `localhost` | Database hostname |
| `ORACLE_PORT` | No | `1521` | Database listener port |
| `ORACLE_SERVICE` | No | `ORCLPDB1` | Database service name |
| `ORACLE_PWD` | Yes* | — | SYS password (\*required on first run only) |
| `ORDS_PWD` | No | (auto-generated) | ORDS_PUBLIC_USER password |

### ORDS Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTEXT_ROOT` | `ords` | Web application context path |
| `DB_WAIT_RETRY` | `60` | Max retries waiting for DB to be reachable (5s between retries) |
| `SETUP_ONLY` | `false` | Set to `true` to configure ORDS without starting Tomcat |

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `FEATURE_SDW` | `true` | SQL Developer Web |
| `FEATURE_DB_API` | `true` | Database REST API |
| `FEATURE_REST_APEX` | `false` | APEX RESTful Services |
| `FEATURE_PLSQL_GATEWAY` | `false` | PL/SQL Gateway |

### TLS (optional)

TLS is disabled by default. Enable it by setting `ENABLE_TLS=true` and mounting a PKCS12 keystore.

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_TLS` | `false` | Set to `true` to enable HTTPS on port 8443 |
| `TLS_KEYSTORE_PASS` | `changeit` | PKCS12 keystore password |

When TLS is enabled, the entrypoint validates that a keystore exists at `/usr/local/tomcat/conf/tls/keystore.p12` and activates the HTTPS connector. When disabled, only the HTTP connector on port 8080 is active.

## Volumes

| Host Path | Container Path | Mode | Description |
|-----------|---------------|------|-------------|
| `/tmp/docker/containers/ords/ords_config` | `/etc/ords/config` | rw | ORDS configuration (persisted across restarts) |
| `/tmp/docker/containers/ords/apex` | `/opt/oracle/apex` | rw | APEX distribution (images served at `/i`) |
| `/tmp/docker/export` | `/export` | rw | Export/scratch space |
| `/etc/timezone` | `/etc/timezone` | ro | Host timezone |
| `./tls/keystore.p12` | `/usr/local/tomcat/conf/tls/keystore.p12` | ro | TLS keystore (optional, only when `ENABLE_TLS=true`) |

## TLS / HTTPS

TLS is optional. The image ships with two Tomcat server configurations (`server-http.xml` and `server-tls.xml`), and the entrypoint selects the appropriate one at runtime based on the `ENABLE_TLS` environment variable.

### Enabling TLS

1. Generate or provide a PKCS12 keystore
2. Set `ENABLE_TLS=true` in `.env`
3. Mount the keystore into the container (uncomment the volume in `docker-compose.yml`)

### Self-signed certificate (development/testing)

```bash
# Generate keystore with defaults (localhost, 365 days)
./generate-self-signed-cert.sh

# Or with custom hostname and password
./generate-self-signed-cert.sh tls/keystore.p12 mypassword myhost.example.com
```

### Production certificate

Convert your PEM certificate and key to a PKCS12 keystore:

```bash
openssl pkcs12 -export \
  -in cert.pem -inkey key.pem -chain -CAfile ca.pem \
  -name tomcat -out tls/keystore.p12 \
  -passout pass:yourpassword
```

Then set `ENABLE_TLS=true` and `TLS_KEYSTORE_PASS=yourpassword` in `.env`, and mount the keystore.

## Startup Behaviour

On first run (no existing config at `/etc/ords/config`):

1. Selects HTTP-only or HTTP+TLS server config based on `ENABLE_TLS`
2. Renames WAR file if `CONTEXT_ROOT` differs from `ords`
3. Waits for the database to be reachable (retries configurable via `DB_WAIT_RETRY`)
4. Validates `ORACLE_PWD` is set (auto-generates `ORDS_PWD` if not provided)
5. Runs `ords install` to configure the database connection and create ORDS schemas
6. Applies feature flags (APEX REST services, PL/SQL Gateway)
7. Runs any custom init scripts from `/ords-entrypoint.d/*.sh`
8. Starts Tomcat in the foreground with graceful shutdown handling (SIGTERM/SIGINT)

On subsequent runs (existing config found):

1. Selects server config based on `ENABLE_TLS`
2. Skips ORDS installation
3. Runs any custom init scripts from `/ords-entrypoint.d/*.sh`
4. Starts Tomcat immediately using the persisted configuration

### Setup-only mode

To configure ORDS without starting Tomcat (useful for pre-provisioning):

```bash
docker run --rm \
  -v /tmp/docker/containers/ords/ords_config:/etc/ords/config \
  -e ORACLE_HOST=mydbhost -e ORACLE_PWD=mysyspassword \
  -e SETUP_ONLY=true \
  tomcat-ords:latest
```

### Custom init scripts

Mount executable `.sh` scripts into `/ords-entrypoint.d/` to run custom logic after ORDS configuration but before Tomcat starts.

## Included Tools

| Tool | Path | Description |
|------|------|-------------|
| ORDS CLI | `/usr/local/bin/ords` | ORDS configuration and administration |
| SQLcl | `/usr/local/bin/sql` | Oracle SQL command-line client |

Access tools inside a running container:

```bash
docker exec -it tomcat-ords ords --config /etc/ords/config config list
docker exec -it tomcat-ords sql sys/<password>@//host:port/service as sysdba
```

## Health Check

The image includes a built-in Docker HEALTHCHECK that tries HTTPS first, then falls back to HTTP:

```
curl -fk https://localhost:8443/ords/ || curl -f http://localhost:8080/ords/
```

- Interval: 30s
- Timeout: 10s
- Retries: 5
- Start period: 60s (allows time for ORDS initial setup)

## Security

- Runs as non-root `oracle` user (UID 54321, group `oinstall` GID 54321)
- Default Tomcat webapps removed (ROOT, docs, examples, manager, host-manager)
- Tomcat shutdown port disabled (`-1`)
- TLS available on port 8443 (TLSv1.3) when enabled
- JVM heap set to 1024MB (Oracle recommended) via `setenv.sh`
- Timezone set to UTC
- Passwords stored in `.env` file (git-ignored)
- Graceful shutdown handling (SIGTERM/SIGINT forwarded to Tomcat)

## Project Files

| File | Description |
|------|-------------|
| `Dockerfile` | Multi-stage build (ORDS image + Tomcat base) |
| `docker-compose.yml` | Compose config with volumes, network, healthcheck |
| `entrypoint.sh` | TLS selection, DB wait, ORDS setup, init scripts, graceful shutdown |
| `server-http.xml` | Tomcat config — HTTP only (port 8080) |
| `server-tls.xml` | Tomcat config — HTTP (8080) + HTTPS (8443) |
| `setenv.sh` | Tomcat JVM options (`-Dconfig.url`, heap, timezone) |
| `buildContainerImage.sh` | Build helper with Docker/Podman detection and proxy support |
| `generate-self-signed-cert.sh` | Creates a PKCS12 keystore with self-signed certificate |
| `.env.example` | Template for environment variables (copy to `.env`) |
| `.dockerignore` | Excludes unnecessary files from Docker build context |

## References

- [ORDS on Tomcat - Oracle-Base Guide](https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat-22-onward)
- [ORDS 25.4 Installation Guide](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/25.4/ordig/installing-and-configuring-oracle-rest-data-services.html)
- [ORDS 25.4 Tomcat Deployment Guide](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/25.4/ordig/deploying-and-monitoring-oracle-rest-data-services.html)
- [Oracle ORDS Container Image](https://container-registry.oracle.com/ords/ocr/ba/database/ords)
- [Oracle APEX Downloads](https://www.oracle.com/tools/downloads/apex-downloads/)

## License

MIT
