#!/bin/bash
# setenv.sh - Tomcat environment configuration for ORDS
#
# This file is automatically sourced by catalina.sh

# ORDS config directory location
CATALINA_OPTS="${CATALINA_OPTS} -Dconfig.url=/etc/ords/config"

# JVM heap size (Oracle recommended)
CATALINA_OPTS="${CATALINA_OPTS} -Xms1024M -Xmx1024M"

# Set timezone to UTC
CATALINA_OPTS="${CATALINA_OPTS} -Duser.timezone=UTC"

export CATALINA_OPTS
