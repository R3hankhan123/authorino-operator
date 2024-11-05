# !/usr/bin/env bash
# Builds the OLM catalog index manifests and pushes it to quay.io.
# To push to your own registry, override the IMG_REGISTRY_HOST , IMG_REGISTRY_ORG , OPERATOR_NAME and TAG env vars,
# i.e:
#   IMG_REGISTRY_HOST=quay.io IMG_REGISTRY_ORG=yourusername OPERATOR_NAME=authorino-operator TAG=latest ./script/build_catalog.sh
#
set -e  # Exit on error
IFS=' ' read -r -a tags <<< "$TAG"
architectures=(${ARCHITECTURES})

for tag in "${tags[@]}"; do
  echo "Creating manifest for $TAG"
  buildah manifest create "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
   for arch in "${architectures[@]}"; do
    # Pull the image for the current architecture
    buildah pull "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-${arch}"
    buildah manifest add "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-${arch}"
    buildah rmi "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-${arch}" || true
  done
  buildah manifest push --all "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}"
  buildah rmi "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}" || true
done
