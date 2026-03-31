#!/bin/bash
# entrypoint.sh - Configure ORDS and start Tomcat
set -e

ORDS_HOME=/opt/oracle/ords
ORDS_CONFIG=/etc/ords/config
CONTEXT_ROOT="${CONTEXT_ROOT:-ords}"

# Rename WAR if context root differs from default
if [ "$CONTEXT_ROOT" != "ords" ]; then
    CONTEXT_ROOT_CLEAN=$(echo "$CONTEXT_ROOT" | tr -d '/')
    if [ -f "${CATALINA_HOME}/webapps/ords.war" ]; then
        mv "${CATALINA_HOME}/webapps/ords.war" "${CATALINA_HOME}/webapps/${CONTEXT_ROOT_CLEAN}.war"
        echo "INFO: Renamed ords.war to ${CONTEXT_ROOT_CLEAN}.war"
    fi
fi

# Configure ORDS if not already configured
if [ ! -f "${ORDS_CONFIG}/databases/default/pool.xml" ]; then
    echo "INFO: No existing ORDS configuration found. Running initial setup..."

    if [ -z "$ORACLE_PWD" ]; then
        echo "ERROR: ORACLE_PWD environment variable is required for initial ORDS setup."
        exit 1
    fi

    ORACLE_HOST="${ORACLE_HOST:-localhost}"
    ORACLE_PORT="${ORACLE_PORT:-1521}"
    ORACLE_SERVICE="${ORACLE_SERVICE:-ORCLPDB1}"

    # Generate ORDS_PUBLIC_USER password if not provided
    if [ -z "$ORDS_PWD" ]; then
        ORDS_PWD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
        echo "INFO: Generated ORDS_PUBLIC_USER password (retrieve via: ords config get --secret db.password)"
    fi

    echo "INFO: Configuring ORDS for ${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}"

    # Set ORDS config directory
    ords --config "${ORDS_CONFIG}" install \
        --admin-user SYS \
        --db-hostname "${ORACLE_HOST}" \
        --db-port "${ORACLE_PORT}" \
        --db-servicename "${ORACLE_SERVICE}" \
        --feature-sdw true \
        --feature-db-api true \
        --password-stdin <<EOF
${ORACLE_PWD}
${ORDS_PWD}
EOF

    echo "INFO: ORDS configuration complete."
else
    echo "INFO: Existing ORDS configuration found at ${ORDS_CONFIG}"
fi

# Execute the CMD (catalina.sh run)
exec "$@"
