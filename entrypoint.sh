#!/bin/bash
# entrypoint.sh - Configure ORDS and start Tomcat
set -e

ORDS_HOME=/opt/oracle/ords
ORDS_CONFIG=/etc/ords/config
CONTEXT_ROOT="${CONTEXT_ROOT:-ords}"
SETUP_ONLY="${SETUP_ONLY:-false}"

# Defaults
ORACLE_HOST="${ORACLE_HOST:-localhost}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_SERVICE="${ORACLE_SERVICE:-ORCLPDB1}"
DB_WAIT_RETRY="${DB_WAIT_RETRY:-60}"
APEXI="${APEXI:-${CATALINA_HOME}/webapps/i}"

# Feature flags (match Oracle's defaults)
FEATURE_SDW="${FEATURE_SDW:-true}"
FEATURE_DB_API="${FEATURE_DB_API:-true}"
FEATURE_REST_APEX="${FEATURE_REST_APEX:-false}"
FEATURE_PLSQL_GATEWAY="${FEATURE_PLSQL_GATEWAY:-false}"

# -------------------------------------------------------------------
# Graceful shutdown - forward SIGTERM to Tomcat
# -------------------------------------------------------------------
shutdown() {
    echo "INFO: Received shutdown signal, stopping Tomcat..."
    if [ -n "$TOMCAT_PID" ]; then
        kill -TERM "$TOMCAT_PID" 2>/dev/null
        wait "$TOMCAT_PID"
    fi
    exit 0
}
trap shutdown SIGTERM SIGINT

# -------------------------------------------------------------------
# Wait for database to be reachable
# -------------------------------------------------------------------
wait_for_db() {
    local retries=${DB_WAIT_RETRY}
    local count=0

    echo "INFO: Waiting for database at ${ORACLE_HOST}:${ORACLE_PORT}..."

    while [ $count -lt $retries ]; do
        if (echo > /dev/tcp/${ORACLE_HOST}/${ORACLE_PORT}) 2>/dev/null; then
            echo "INFO: Database listener is reachable."
            return 0
        fi
        count=$((count + 1))
        echo "INFO: Database not ready, retry ${count}/${retries}..."
        sleep 5
    done

    echo "ERROR: Database at ${ORACLE_HOST}:${ORACLE_PORT} not reachable after ${retries} retries."
    return 1
}

# -------------------------------------------------------------------
# Configure TLS if enabled
# -------------------------------------------------------------------
ENABLE_TLS="${ENABLE_TLS:-false}"
if [ "${ENABLE_TLS}" = "true" ]; then
    if [ -f "${CATALINA_HOME}/conf/tls/keystore.p12" ]; then
        echo "INFO: TLS enabled - activating HTTPS on port 8443"
        cp "${CATALINA_HOME}/conf/server-tls.xml" "${CATALINA_HOME}/conf/server.xml"
    else
        echo "ERROR: ENABLE_TLS=true but no keystore found at ${CATALINA_HOME}/conf/tls/keystore.p12"
        echo "       Mount a keystore or generate one with: ./generate-self-signed-cert.sh"
        exit 1
    fi
else
    echo "INFO: TLS disabled - HTTP only on port 8080"
    cp "${CATALINA_HOME}/conf/server-http.xml" "${CATALINA_HOME}/conf/server.xml"
fi

# -------------------------------------------------------------------
# Rename WAR if context root differs from default
# -------------------------------------------------------------------
if [ "$CONTEXT_ROOT" != "ords" ]; then
    CONTEXT_ROOT_CLEAN=$(echo "$CONTEXT_ROOT" | tr -d '/')
    if [ -f "${CATALINA_HOME}/webapps/ords.war" ]; then
        mv "${CATALINA_HOME}/webapps/ords.war" "${CATALINA_HOME}/webapps/${CONTEXT_ROOT_CLEAN}.war"
        echo "INFO: Renamed ords.war to ${CONTEXT_ROOT_CLEAN}.war"
    fi
fi

# -------------------------------------------------------------------
# Configure ORDS if not already configured
# -------------------------------------------------------------------
if [ ! -f "${ORDS_CONFIG}/databases/default/pool.xml" ]; then
    echo "INFO: No existing ORDS configuration found. Running initial setup..."

    if [ -z "$ORACLE_PWD" ]; then
        echo "ERROR: ORACLE_PWD environment variable is required for initial ORDS setup."
        exit 1
    fi

    # Generate ORDS_PUBLIC_USER password if not provided
    if [ -z "$ORDS_PWD" ]; then
        ORDS_PWD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
        echo "INFO: Generated ORDS_PUBLIC_USER password."
        echo "INFO: Retrieve with: docker exec <container> ords --config ${ORDS_CONFIG} config get --secret db.password"
    fi

    # Wait for database before attempting install
    wait_for_db

    echo "INFO: Configuring ORDS for ${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}"
    echo "INFO: Features: SDW=${FEATURE_SDW} DB-API=${FEATURE_DB_API} APEX-REST=${FEATURE_REST_APEX} PLSQL-GW=${FEATURE_PLSQL_GATEWAY}"

    ords --config "${ORDS_CONFIG}" install \
        --admin-user SYS \
        --db-hostname "${ORACLE_HOST}" \
        --db-port "${ORACLE_PORT}" \
        --db-servicename "${ORACLE_SERVICE}" \
        --feature-sdw "${FEATURE_SDW}" \
        --feature-db-api "${FEATURE_DB_API}" \
        --password-stdin <<EOF
${ORACLE_PWD}
${ORDS_PWD}
EOF

    # Enable APEX REST services if requested
    if [ "${FEATURE_REST_APEX}" = "true" ]; then
        echo "INFO: Enabling APEX RESTful Services..."
        ords --config "${ORDS_CONFIG}" config set restEnabledSql.active true
    fi

    # Enable PL/SQL Gateway if requested
    if [ "${FEATURE_PLSQL_GATEWAY}" = "true" ]; then
        echo "INFO: Enabling PL/SQL Gateway..."
        ords --config "${ORDS_CONFIG}" config set plsql.gateway.mode proxied
    fi

    echo "INFO: ORDS configuration complete."
else
    echo "INFO: Existing ORDS configuration found at ${ORDS_CONFIG}"
fi

# -------------------------------------------------------------------
# Run any user-provided init scripts from /ords-entrypoint.d/
# -------------------------------------------------------------------
if [ -d "/ords-entrypoint.d" ]; then
    for f in /ords-entrypoint.d/*.sh; do
        if [ -x "$f" ]; then
            echo "INFO: Running init script: $f"
            "$f"
        fi
    done
fi

# -------------------------------------------------------------------
# Setup-only mode: configure but don't start Tomcat
# -------------------------------------------------------------------
if [ "${SETUP_ONLY}" = "true" ]; then
    echo "INFO: Setup-only mode. ORDS configured but Tomcat not started."
    exit 0
fi

# -------------------------------------------------------------------
# Start Tomcat
# -------------------------------------------------------------------
echo "INFO: Starting Tomcat with ORDS at /${CONTEXT_ROOT}"
exec "$@" &
TOMCAT_PID=$!
wait "$TOMCAT_PID"
