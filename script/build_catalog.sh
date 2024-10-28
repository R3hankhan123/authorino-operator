#!/usr/bin/env bash
# Builds the OLM catalog index and pushes it to quay.io.

# Iterate over tag list, i.e., latest 0e972a42f51453a8cea5e6df7f8f6ce6eb1b4075
IFS=' ' read -r -a tags <<< "$TAG"

# Use the first tag to create the manifest and push images.
first_tag="${tags[0]}"

# Build & push catalog images for each architecture using make.
for arch in amd64 ppc64le arm64 s390x; do
  # Pass the architecture to the Makefile
  make catalog-multiarch arch="${arch}" 
  # Push the catalog image after building
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  make catalog-build-multi IMG="${image_tag}"
  docker push "${image_tag}"
done

# Create and push a multi-architecture manifest for the first tag.
docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-amd64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-arm64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-ppc64le" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-s390x"

docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"

# Delete the catalog images after amending the manifest
for arch in amd64 ppc64le arm64 s390x; do
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
  docker rmi "${image_tag}" || true
done

# Annotate and push the same manifest for other tags.
for tag in "${tags[@]:1}"; do
  docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" \
    --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"

  docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"

  # Delete the catalog image after amending the manifest
  image_tag="${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
  docker rmi "${image_tag}" || true
done
