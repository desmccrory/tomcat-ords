# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

 Project firstly to create a docker image containing latest Apache Tomcat app and latest Oracle ORDS App in readiness to configure and deploy combined solution.
 Secondly to document and configure deployment steps

 Source base image from  container-registry.oracle.com
 eg docker pull container-registry.oracle.com/database/ords:latest
 refer https://container-registry.oracle.com/ords/ocr/ba/database/ords

## Background

Reference guide
https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat-22-onward
ORDS Installation guide
https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/25.4/ordig/installing-and-configuring-oracle-rest-data-services.html#GUID-B6661F35-3EE3-4CB3-9379-40D0B8E24635
Tomcat Installation guide
https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/25.4/ordig/deploying-and-monitoring-oracle-rest-data-services.html#GUID-3F2AE730-69D0-4A64-A13A-76745B7467CD

See also sample project at folder /Users/dmccrory/Documents/Projects/tomcat-ords-image

plan first, then build then test
use git and github to manage project source. Use primarily bash scripting and linux commands with python as and when required
Ask question if there are options or you need clarification

