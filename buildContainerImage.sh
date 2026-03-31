#!/bin/bash
# buildContainerImage.sh - Build the Tomcat + ORDS Docker image
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="tomcat-ords"
IMAGE_TAG="latest"

usage() {
    echo "Usage: $0 [-t tag] [-n name] [-o build_options] [-h]"
    echo ""
    echo "Options:"
    echo "  -t tag              Image tag (default: latest)"
    echo "  -n name             Image name (default: tomcat-ords)"
    echo "  -o build_options    Additional Docker build options"
    echo "  -h                  Show this help"
    exit 1
}

while getopts "t:n:o:h" opt; do
    case $opt in
        t) IMAGE_TAG="$OPTARG" ;;
        n) IMAGE_NAME="$OPTARG" ;;
        o) BUILD_OPTS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check for apex-latest.zip
if [ ! -f "${SCRIPT_DIR}/apex-latest.zip" ]; then
    echo "ERROR: apex-latest.zip not found in ${SCRIPT_DIR}"
    echo "Download APEX from Oracle and place apex-latest.zip in this directory."
    exit 1
fi

# Detect container runtime
if command -v docker &>/dev/null; then
    CONTAINER_RT="docker"
elif command -v podman &>/dev/null; then
    CONTAINER_RT="podman"
else
    echo "ERROR: Neither docker nor podman found in PATH."
    exit 1
fi

echo "============================================"
echo "Building ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Container runtime: ${CONTAINER_RT}"
echo "============================================"

# Build with proxy support if set
PROXY_ARGS=""
[ -n "$http_proxy" ]  && PROXY_ARGS="${PROXY_ARGS} --build-arg http_proxy=${http_proxy}"
[ -n "$https_proxy" ] && PROXY_ARGS="${PROXY_ARGS} --build-arg https_proxy=${https_proxy}"
[ -n "$no_proxy" ]    && PROXY_ARGS="${PROXY_ARGS} --build-arg no_proxy=${no_proxy}"

${CONTAINER_RT} build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    ${PROXY_ARGS} \
    ${BUILD_OPTS} \
    "${SCRIPT_DIR}"

echo ""
echo "============================================"
echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Run with:"
echo "  ${CONTAINER_RT} run -p 8080:8080 \\"
echo "    -e ORACLE_HOST=<db_host> \\"
echo "    -e ORACLE_PWD=<sys_password> \\"
echo "    -e ORACLE_SERVICE=<service_name> \\"
echo "    ${IMAGE_NAME}:${IMAGE_TAG}"
echo "============================================"
