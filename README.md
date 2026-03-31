# Tomcat + ORDS Docker Image

Docker image combining Apache Tomcat 9 with Oracle REST Data Services (ORDS) 25.4 and APEX static images.

## Prerequisites

- Docker or Podman
- `apex-latest.zip` downloaded from [Oracle APEX Downloads](https://www.oracle.com/tools/downloads/apex-downloads/) and placed in this directory
- Access to `container-registry.oracle.com/database/ords:latest` (login required: `docker login container-registry.oracle.com`)

## Build

```bash
./buildContainerImage.sh
```

Or directly:

```bash
docker build -t tomcat-ords:latest .
```

## Run

```bash
docker run -p 8080:8080 \
  -e ORACLE_HOST=mydbhost \
  -e ORACLE_PORT=1521 \
  -e ORACLE_SERVICE=ORCLPDB1 \
  -e ORACLE_PWD=mysyspassword \
  tomcat-ords:latest
```

Access ORDS at: `http://localhost:8080/ords/`

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ORACLE_HOST` | No | `localhost` | Database hostname |
| `ORACLE_PORT` | No | `1521` | Database listener port |
| `ORACLE_SERVICE` | No | `ORCLPDB1` | Database service name |
| `ORACLE_PWD` | Yes* | - | SYS password (*required on first run) |
| `ORDS_PWD` | No | (generated) | ORDS_PUBLIC_USER password |
| `CONTEXT_ROOT` | No | `ords` | Web context path |

## Persistent Configuration

Mount a volume at `/etc/ords/config` to persist ORDS configuration across container restarts:

```bash
docker run -p 8080:8080 \
  -v ords-config:/etc/ords/config \
  -e ORACLE_HOST=mydbhost \
  -e ORACLE_PWD=mysyspassword \
  tomcat-ords:latest
```

## Architecture

- **Base**: Official Tomcat 9 with JDK 17 (Temurin)
- **ORDS**: Extracted from Oracle's official ORDS container image
- **APEX Images**: Served at `/i` context path
- **SQLcl**: Included for database administration
- **Config**: Passed to ORDS via `-Dconfig.url` in Tomcat's `setenv.sh`
