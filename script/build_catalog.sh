#!/usr/bin/env bash
# Builds the OLM catalog index and pushes it to quay.io.

set -e  # Exit on error

# Split tags into an array
IFS=' ' read -r -a tags <<< "$TAG"
first_tag="${tags[0]}"

# Build and push catalog images for each architecture
for arch in amd64 ppc64le arm64 s390x; do
  # Pass the architecture to the Makefile and push images
  make catalog-multiarch arch="${arch}"
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  make catalog-build-multi IMG="${image_tag}"
  docker push "${image_tag}" &
done

# Create and push multi-architecture manifest
docker manifest create ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag} \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-amd64 \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-arm64  \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-ppc64le \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-s390x

docker manifest push ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}

# Tag and push the manifest for additional tags
for tag in "${tags[@]:1}"; do
  docker tag "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}" "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
  docker push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" &
  docker rmi "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" || true
done

# Clean up architecture-specific images
for arch in amd64 ppc64le arm64 s390x; do
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  docker rmi "${image_tag}" || true
done
docker rmi "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" || true
