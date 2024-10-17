#!/usr/bin/env bash
set -e

# Builds the OLM catalog index and pushes it to quay.io.

# Ensure required environment variables are set
if [ -z "${TAG}" ] || [ -z "${IMG_REGISTRY_HOST}" ] || [ -z "${IMG_REGISTRY_ORG}" ] || [ -z "${OPERATOR_NAME}" ]; then
    echo "Error: Required environment variables are not set"
    echo "Please ensure TAG, IMG_REGISTRY_HOST, IMG_REGISTRY_ORG, and OPERATOR_NAME are set"
    exit 1
fi

# Iterate over tag list, i.e., latest 0e972a42f51453a8cea5e6df7f8f6ce6eb1b4075
IFS=' ' read -r -a tags <<< "$TAG"

# Set up directory paths
PROJECT_DIR=$(dirname "$(realpath "$0")")
CATALOG_DIR="${PROJECT_DIR}/catalog/authorino-operator-catalog"
CATALOG_FILE="${CATALOG_DIR}/operator.yaml"
CATALOG_DOCKERFILE="${PROJECT_DIR}/catalog/authorino-operator-catalog.Dockerfile"

# Use the first tag to create the manifest and push images
first_tag="${tags[0]}"
BUNDLE_IMG="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${first_tag}"

# Ensure required binaries exist and are executable
YQ="${PROJECT_DIR}/bin/yq"
OPM="${PROJECT_DIR}/bin/opm"
if [ ! -f "$YQ" ]; then
    echo "Error: yq binary not found at $YQ"
    echo "Current directory: $(pwd)"
    echo "PROJECT_DIR: ${PROJECT_DIR}"
    ls -la "${PROJECT_DIR}/bin" || echo "bin directory not found"
    exit 1
fi

if [ ! -f "$OPM" ]; then
    echo "Error: opm binary not found at $OPM"
    echo "Current directory: $(pwd)"
    echo "PROJECT_DIR: ${PROJECT_DIR}"
    ls -la "${PROJECT_DIR}/bin" || echo "bin directory not found"
    exit 1
fi

chmod +x "$YQ" "$OPM" || echo "Failed to set executable permissions"


# Build & push catalog images for each architecture
for arch in amd64 ppc64le arm64 s390x; do
    echo "Building catalog for architecture: $arch"
    
    # Clean up and create fresh directory
    rm -rf "${CATALOG_DIR}"
    rm -f "${CATALOG_DOCKERFILE}"
    mkdir -p "${CATALOG_DIR}"
    
    # Generate dockerfile
    cd "${PROJECT_DIR}/catalog" || exit 1
    "${OPM}" generate dockerfile authorino-operator-catalog -i "quay.io/operator-framework/opm:v1.28.0-${arch}"
    
    echo "************************************************************"
    echo "Build authorino operator catalog"
    echo "BUNDLE_IMG                  = ${BUNDLE_IMG}"
    echo "CHANNELS                    = ${CHANNELS}"
    echo "ARCHITECTURE                = ${arch}"
    echo "************************************************************"
    
    # Generate catalog
    GENERATE_SCRIPT="${PROJECT_DIR}/utils/generate-catalog.sh"
    if [ ! -f "$GENERATE_SCRIPT" ]; then
        echo "Error: generate-catalog.sh script not found at $GENERATE_SCRIPT"
        exit 1
    fi
    
    bash "$GENERATE_SCRIPT" "${OPM}" "${YQ}" "${BUNDLE_IMG}" "${CHANNELS}"
    
    # Build and push the image
    if [ ! -f "${CATALOG_DOCKERFILE}" ]; then
        echo "Error: Dockerfile not found at ${CATALOG_DOCKERFILE}"
        exit 1
    }
    
    docker build "${PROJECT_DIR}/catalog" \
        -f "${CATALOG_DOCKERFILE}" \
        -t "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
    
    docker push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
done

# Create and push a multi-architecture manifest
echo "Creating multi-arch manifest for tag: ${first_tag}"
docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}" \
    "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-amd64" \
    "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-arm64" \
    "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-ppc64le" \
    "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-s390x"

docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"

# Handle additional tags
for tag in "${tags[@]:1}"; do
    echo "Creating manifest for additional tag: ${tag}"
    docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" \
        --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"
    
    docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
done
