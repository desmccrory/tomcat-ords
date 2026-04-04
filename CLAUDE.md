# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Docker image combining Apache Tomcat 9 with Oracle REST Data Services (ORDS) 25.4 and APEX static images. Multi-stage build using Oracle's official ORDS container image as source, deployed onto a Tomcat 9 + JDK 17 base.

## Architecture

- **Stage 1**: Extracts ORDS WAR, CLI, SQLcl from `container-registry.oracle.com/database/ords:latest`
- **Stage 2**: Builds on `tomcat:9-jdk17-temurin`, deploys ords.war to Tomcat webapps
- APEX static images extracted from `apex-latest.zip` into `/i` context
- ORDS config linked via `-Dconfig.url=/etc/ords/config` in `setenv.sh`
- Tomcat 9 required (not 10+) because ORDS 25.4 uses `javax.servlet`

## Key Files

- `Dockerfile` - Multi-stage build definition
- `entrypoint.sh` - ORDS initial config + Tomcat startup
- `setenv.sh` - Tomcat JVM options (heap, timezone, config.url)
- `buildContainerImage.sh` - Build helper (Docker/Podman, proxy support)
- `apex-latest.zip` - APEX distribution (not in git, required for build)

## Common Commands

```bash
# Build
./buildContainerImage.sh
# or
docker build -t tomcat-ords:latest .

# Run
docker run -p 8080:8080 \
  -e ORACLE_HOST=<db_host> \
  -e ORACLE_PWD=<sys_password> \
  -e ORACLE_SERVICE=<service_name> \
  -v ords-config:/etc/ords/config \
  tomcat-ords:latest

# Verify
curl http://localhost:8080/ords/
```

## Prerequisites

- `apex-latest.zip` must be downloaded from Oracle and placed in project root
- Docker login to `container-registry.oracle.com` required for ORDS base image

## Reference Guides

- https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat-22-onward
- https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/25.4/ordig/installing-and-configuring-oracle-rest-data-services.html
- https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/25.4/ordig/deploying-and-monitoring-oracle-rest-data-services.html

See also sample standalone project at `/Users/dmccrory/Documents/Projects/tomcat-ords-image`

## Working Preferences

- Plan first, then build, then test
- Use git and GitHub to manage project source
- Use primarily bash scripting and Linux commands with Python as needed
- Ask questions if there are options or clarification is needed
