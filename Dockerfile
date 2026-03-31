# Stage 1: Extract ORDS artifacts from Oracle's official image
FROM container-registry.oracle.com/database/ords:latest AS ords-source

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
    ORACLE_SERVICE=ORCLPDB1

# Create oracle user/group matching the ORDS image
RUN groupadd -f -g 54321 oinstall && \
    useradd -u 54321 -g oinstall -c "Oracle Software Owner" -m oracle

# Create directories
RUN mkdir -p ${ORDS_HOME}/bin ${ORDS_HOME}/lib ${ORDS_CONFIG} && \
    chown -R oracle:oinstall ${ORDS_HOME} ${ORDS_CONFIG}

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

# Extract APEX images into Tomcat webapps/i/
COPY apex-latest.zip /tmp/apex-latest.zip
RUN mkdir -p ${CATALINA_HOME}/webapps/i && \
    cd /tmp && \
    jar xf apex-latest.zip && \
    cp -r /tmp/apex/images/* ${CATALINA_HOME}/webapps/i/ && \
    rm -rf /tmp/apex /tmp/apex-latest.zip /tmp/META-INF

# Remove default Tomcat webapps (security hardening)
RUN rm -rf ${CATALINA_HOME}/webapps/ROOT \
           ${CATALINA_HOME}/webapps/docs \
           ${CATALINA_HOME}/webapps/examples \
           ${CATALINA_HOME}/webapps/host-manager \
           ${CATALINA_HOME}/webapps/manager

# Copy configuration files
COPY setenv.sh ${CATALINA_HOME}/bin/setenv.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x ${CATALINA_HOME}/bin/setenv.sh /usr/local/bin/entrypoint.sh

# Set ownership
RUN chown -R oracle:oinstall ${CATALINA_HOME} ${ORDS_HOME} ${ORDS_CONFIG}

# Run as oracle user
USER oracle

# Config volume for persistence
VOLUME ${ORDS_CONFIG}

EXPOSE 8080

ENTRYPOINT ["entrypoint.sh"]
CMD ["catalina.sh", "run"]
