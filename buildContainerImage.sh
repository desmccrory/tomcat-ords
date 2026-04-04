#!/bin/bash
# buildContainerImage.sh - Build the Tomcat + ORDS Docker image
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="tomcat-ords"
IMAGE_TAG="latest"
ORDS_IMAGE="container-registry.oracle.com/database/ords:latest"

usage() {
    echo "Usage: $0 [-t tag] [-n name] [-s ords_image] [-o build_options] [-h]"
    echo ""
    echo "Options:"
    echo "  -t tag              Image tag (default: latest)"
    echo "  -n name             Image name (default: tomcat-ords)"
    echo "  -s ords_image       Source ORDS image (default: container-registry.oracle.com/database/ords:latest)"
    echo "  -o build_options    Additional Docker build options"
    echo "  -h                  Show this help"
    exit 1
}

while getopts "t:n:s:o:h" opt; do
    case $opt in
        t) IMAGE_TAG="$OPTARG" ;;
        n) IMAGE_NAME="$OPTARG" ;;
        s) ORDS_IMAGE="$OPTARG" ;;
        o) BUILD_OPTS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Detect container runtime
if command -v docker &>/dev/null; then
    CONTAINER_RT="docker"
elif command -v podman &>/dev/null; then
    CONTAINER_RT="podman"
else
    echo "ERROR: Neither docker nor podman found in PATH."
    exit 1
fi

# Check ORDS image exists locally
if ! ${CONTAINER_RT} image inspect "${ORDS_IMAGE}" &>/dev/null; then
    echo "ERROR: ORDS image '${ORDS_IMAGE}' not found locally."
    echo ""
    echo "Pull it manually (requires one-time Oracle T&C acceptance):"
    echo "  1. Accept terms at https://container-registry.oracle.com/ords/ocr/ba/database/ords"
    echo "  2. ${CONTAINER_RT} login container-registry.oracle.com"
    echo "  3. ${CONTAINER_RT} pull ${ORDS_IMAGE}"
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
    --build-arg ORDS_IMAGE="${ORDS_IMAGE}" \
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
