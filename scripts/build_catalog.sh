#!/usr/bin/env bash
# Builds the OLM catalog index and pushes it to quay.io.
#
# To push to your own registry, override the IMG_REGISTRY_HOST, IMG_REGISTRY_ORG, OPERATOR_NAME, and TAG env vars,
# i.e:
#   IMG_REGISTRY_HOST=quay.io IMG_REGISTRY_ORG=yourusername OPERATOR_NAME=authorino-operator TAG="latest 0e972a42f51453a8cea5e6df7f8f6ce6eb1b4075" ./script/build_catalog.sh
#
# REQUIREMENTS:
#  * A valid login session to a container registry.
#  * Docker
#  * opm

# Iterate over tag list, i.e., latest 0e972a42f51453a8cea5e6df7f8f6ce6eb1b4075
IFS=' ' read -r -a tags <<< "$TAG"

# Build & push catalog images for each architecture using the first tag only.
first_tag="${tags[0]}"
for arch in amd64 ppc64le arm64 s390x; do
  opm index add --build-tool docker \
    --tag "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}" \
    --bundles "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${first_tag}" \
    --binary-image "quay.io/operator-framework/opm:v1.26.2-${arch}"
  
  #docker push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-${arch}"
done

# Create and push a multi-architecture manifest for the first tag.
docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-amd64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-arm64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-ppc64le" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-s390x"

docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}"

# Re-tag the existing manifest with the remaining tags without rebuilding.
tag="${tags[1]}"
  # Create and push a new manifest that references the same architecture-specific images.
docker manifest create --amend "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-amd64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-arm64" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-ppc64le" \
  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${first_tag}-s390x"

  docker manifest push "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
