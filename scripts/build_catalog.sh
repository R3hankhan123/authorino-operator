#!/usr/bin/env bash
# Builds the OLM catalog index and pushes it to quay.io.

# Iterate over tag list, i.e., latest 0e972a42f51453a8cea5e6df7f8f6ce6eb1b4075
IFS=' ' read -r -a tags <<< "$TAG"
PROJECT_DIR=$(dirname "$(realpath "$0")")
CATALOG_FILE="${PROJECT_DIR}/catalog/authorino-operator-catalog/operator.yaml"
CATALOG_DOCKERFILE="${PROJECT_DIR}/catalog/authorino-operator-catalog.Dockerfile"
# Use the first tag to create the manifest and push images.
first_tag="${tags[0]}"
BUNDLE_IMG="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${first_tag}"

# Build & push catalog images for each architecture.
for arch in amd64 ppc64le arm64 s390x; do
  rm -rf "${PROJECT_DIR}/catalog/authorino-operator-catalog"
  rm -rf "${PROJECT_DIR}/catalog/authorino-operator-catalog.Dockerfile"
  mkdir -p "${PROJECT_DIR}/catalog/authorino-operator-catalog"
  cd "${PROJECT_DIR}/catalog" && opm generate dockerfile authorino-operator-catalog -i "quay.io/operator-framework/opm:v1.28.0-${arch}"
  
  echo "************************************************************"
  echo "Build authorino operator catalog"
  echo "BUNDLE_IMG                  = ${BUNDLE_IMG}"
  echo "CHANNELS                    = ${CHANNELS}"
  echo "************************************************************"
  echo
  echo "Please check this matches your expectations and override variables if needed."
  echo
  
  "${PROJECT_DIR}/utils/generate-catalog.sh" "${OPM}" "${YQ}" "${BUNDLE_IMG}" "$@" "${CHANNELS}"
  
  docker build "${PROJECT_DIR}/catalog" -f "${CATALOG_DOCKERFILE}" -t "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  docker push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
done

# Create and push a multi-architecture manifest for the first tag.
docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-amd64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-arm64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-ppc64le" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-s390x"

docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"

# Annotate and push the same manifest for other tags.
for tag in "${tags[@]:1}"; do
  docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" \
    --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"
  
  docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
done
