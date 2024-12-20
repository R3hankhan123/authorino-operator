#!/usr/bin/env bash
# Builds the OLM catalog index and pushes it to quay.io.

set -e  # Exit on error

# Split tags into an array
IFS=' ' read -r -a tags <<< "$TAG"
first_tag="${tags[0]}"
architectures=(${ARCHITECTURES})
# Build and push catalog images for each architecture
for arch in "${architectures[@]}"; do 
  make catalog-multiarch arch="${arch}"
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  make catalog-build CATALOG_IMG="${image_tag}"
  docker push "${image_tag}" &
  wait
done

# Tag and push the manifest for additional tags
for tag in "${tags[@]}"; do
  echo "Creating manifest for $TAG"
   docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" \
                    $(for arch in "${architectures[@]}"; do
                      echo "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
                     done)
  docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
  docker rmi "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" || true
done

# Clean up architecture-specific images
for arch in "${architectures[@]}"; do
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  docker rmi "${image_tag}" || true
done
