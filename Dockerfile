# Stage 1: Extract ORDS artifacts from a locally-pulled Oracle ORDS image.
# The ORDS image must be pulled manually before building:
#   1. Accept Oracle Standard Terms at https://container-registry.oracle.com/ords/ocr/ba/database/ords
#   2. docker login container-registry.oracle.com
#   3. docker pull container-registry.oracle.com/database/ords:latest
ARG ORDS_IMAGE=container-registry.oracle.com/database/ords:latest
FROM ${ORDS_IMAGE} AS ords-source

# Stage 2: Build Tomcat + ORDS image
FROM tomcat:9-jdk17-temurin

LABEL maintainer="Des McCrory"
LABEL description="Apache Tomcat with Oracle REST Data Services (ORDS) and APEX"

# Environment
ENV ORDS_HOME=/opt/oracle/ords \
    ORDS_CONFIG=/etc/ords/config \
    CONTEXT_ROOT=ords \
    ORACLE_HOST=localhost \
    ORACLE_PORT=1521 \
    ORACLE_SERVICE=ORCLPDB1 \
    DB_WAIT_RETRY=60 \
    SETUP_ONLY=false \
    FEATURE_SDW=true \
    FEATURE_DB_API=true \
    FEATURE_REST_APEX=false \
    FEATURE_PLSQL_GATEWAY=false \
    ENABLE_TLS=false

# Create oracle user/group matching the ORDS image
RUN groupadd -f -g 54321 oinstall && \
    useradd -u 54321 -g oinstall -c "Oracle Software Owner" -m oracle

# Create directories for ORDS, volumes, mount points, and entrypoint hooks
RUN mkdir -p ${ORDS_HOME}/bin ${ORDS_HOME}/lib ${ORDS_HOME}/doc_root \
             ${ORDS_CONFIG} /opt/oracle/apex /export /ords-entrypoint.d && \
    chown -R oracle:oinstall ${ORDS_HOME} ${ORDS_CONFIG} \
             /opt/oracle/apex /export /ords-entrypoint.d

# Copy ORDS artifacts from Stage 1
COPY --from=ords-source /opt/oracle/ords/ords.war ${ORDS_HOME}/ords.war
COPY --from=ords-source /opt/oracle/ords/bin/ ${ORDS_HOME}/bin/
COPY --from=ords-source /opt/oracle/ords/lib/ ${ORDS_HOME}/lib/
COPY --from=ords-source /opt/oracle/ords/scripts/ ${ORDS_HOME}/scripts/

# Copy SQLcl
COPY --from=ords-source /opt/oracle/sqlcl/ /opt/oracle/sqlcl/

# Add ords and sql to PATH
RUN ln -sf ${ORDS_HOME}/bin/ords /usr/local/bin/ords && \
    ln -sf /opt/oracle/sqlcl/bin/sql /usr/local/bin/sql

# Deploy ords.war to Tomcat webapps
RUN cp ${ORDS_HOME}/ords.war ${CATALINA_HOME}/webapps/ords.war

# Symlink Tomcat /i context to APEX images from volume mount at /opt/oracle/apex/images
RUN ln -sf /opt/oracle/apex/images ${CATALINA_HOME}/webapps/i

# Remove default Tomcat webapps (security hardening) and install curl for healthcheck
RUN rm -rf ${CATALINA_HOME}/webapps/ROOT \
           ${CATALINA_HOME}/webapps/docs \
           ${CATALINA_HOME}/webapps/examples \
           ${CATALINA_HOME}/webapps/host-manager \
           ${CATALINA_HOME}/webapps/manager && \
    apt-get update -q && apt-get install -yq --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# TLS configuration (optional)
# To enable: set ENABLE_TLS=true and provide a keystore
# Generate self-signed with: ./generate-self-signed-cert.sh
ARG TLS_KEYSTORE_PASS=changeit
ENV TLS_KEYSTORE_PASS=${TLS_KEYSTORE_PASS}

# Copy both server configs - entrypoint selects based on ENABLE_TLS
RUN mkdir -p ${CATALINA_HOME}/conf/tls
COPY server-http.xml ${CATALINA_HOME}/conf/server-http.xml
COPY server-tls.xml ${CATALINA_HOME}/conf/server-tls.xml

# Default to HTTP-only
RUN cp ${CATALINA_HOME}/conf/server-http.xml ${CATALINA_HOME}/conf/server.xml

# Copy configuration files
COPY setenv.sh ${CATALINA_HOME}/bin/setenv.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x ${CATALINA_HOME}/bin/setenv.sh /usr/local/bin/entrypoint.sh

# Set ownership
RUN chown -R oracle:oinstall ${CATALINA_HOME} ${ORDS_HOME} ${ORDS_CONFIG}

# Run as oracle user
USER oracle

# Volume mount points
VOLUME ${ORDS_CONFIG}
VOLUME /opt/oracle/apex
VOLUME /export

EXPOSE 8080 8443

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD curl -fk https://localhost:8443/ords/ || curl -f http://localhost:8080/ords/ || exit 1

ENTRYPOINT ["entrypoint.sh"]
CMD ["catalina.sh", "run"]
