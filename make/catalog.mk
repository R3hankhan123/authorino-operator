##@ Operator Catalog

# The image tag given to the resulting catalog image (e.g. make catalog-build CATALOG_IMG=example.com/operator-catalog:v0.2.0).
CATALOG_IMG ?= $(IMAGE_TAG_BASE)-catalog:$(IMAGE_TAG)

CATALOG_FILE = $(PROJECT_DIR)/catalog/authorino-operator-catalog/operator.yaml
CATALOG_DOCKERFILE = $(PROJECT_DIR)/catalog/authorino-operator-catalog.Dockerfile

# Generate catalog Dockerfile for single architecture.
$(CATALOG_DOCKERFILE): $(OPM)
	-mkdir -p $(PROJECT_DIR)/catalog/authorino-operator-catalog
	cd $(PROJECT_DIR)/catalog && $(OPM) generate dockerfile authorino-operator-catalog
catalog-dockerfile: $(CATALOG_DOCKERFILE) ## Generate catalog Dockerfile.

# Generate catalog Dockerfile for multiple architectures.
$(CATALOG_DOCKERFILE_MULTI): $(OPM)
	@echo "Running for ${arch}"
	-mkdir -p $(PROJECT_DIR)/catalog/authorino-operator-catalog
	cd $(PROJECT_DIR)/catalog && $(OPM) generate dockerfile authorino-operator-catalog -i "quay.io/operator-framework/opm:v1.28.0-${arch}"
catalog-dockerfile-multi: $(CATALOG_DOCKERFILE_MULTI) ## Generate catalog Dockerfile for multiarch.

# Generate the catalog file.
$(CATALOG_FILE): $(OPM) $(YQ)
	@echo "************************************************************"
	@echo "Build authorino operator catalog"
	@echo
	@echo "BUNDLE_IMG = $(BUNDLE_IMG)"
	@echo "CHANNELS   = $(CHANNELS)"
	@echo "************************************************************"
	@echo
	@echo "Please check this matches your expectations and override variables if needed."
	@echo
	$(PROJECT_DIR)/utils/generate-catalog.sh $(OPM) $(YQ) $(BUNDLE_IMG) $@ $(CHANNELS)

.PHONY: catalog
catalog: $(OPM) ## Generate catalog content and validate.
	# Initializing the Catalog
	-rm -rf $(PROJECT_DIR)/catalog/authorino-operator-catalog
	-rm -rf $(PROJECT_DIR)/catalog/authorino-operator-catalog.Dockerfile
	$(MAKE) catalog-dockerfile
	$(MAKE) $(CATALOG_FILE) BUNDLE_IMG=$(BUNDLE_IMG)
	cd $(PROJECT_DIR)/catalog && $(OPM) validate authorino-operator-catalog

.PHONY: catalog-multiarch
catalog-multiarch: $(OPM) ## Generate catalog content and validate for multiple architectures.
	#Initializing the Catalog
	-rm -rf $(PROJECT_DIR)/catalog/authorino-operator-catalog
	-rm -rf $(PROJECT_DIR)/catalog/authorino-operator-catalog.Dockerfile
	$(MAKE) catalog-dockerfile-multi arch=$(arch)
	@echo "creating dir"
	$(MAKE) $(CATALOG_FILE) BUNDLE_IMG=$(BUNDLE_IMG)
	@echo "leaving dir"
	cd $(PROJECT_DIR)/catalog && $(OPM) validate authorino-operator-catalog


# Build a catalog image.
.PHONY: catalog-build
catalog-build: ## Build a catalog image.
	# Build the Catalog
	docker build $(PROJECT_DIR)/catalog -f $(PROJECT_DIR)/catalog/authorino-operator-catalog.Dockerfile -t $(CATALOG_IMG)

.PHONY: catalog-build-multi
catalog-build-multi: ## Build a multiarch catalog image.
	# Build the Catalog
	docker build $(PROJECT_DIR)/catalog -f $(PROJECT_DIR)/catalog/authorino-operator-catalog.Dockerfile -t $(IMG)

# Push the catalog image.
.PHONY: catalog-push
catalog-push: ## Push a catalog image.
	$(MAKE) docker-push IMG=$(CATALOG_IMG)

# Deploy the catalog to a Kubernetes cluster.
.PHONY: deploy-catalog
deploy-catalog: $(KUSTOMIZE) $(YQ) ## Deploy operator to the K8s cluster specified in ~/.kube/config using OLM catalog image.
	V="$(CATALOG_IMG)" $(YQ) eval '.spec.image = strenv(V)' -i config/deploy/olm/catalogsource.yaml
	$(KUSTOMIZE) build config/deploy/olm | kubectl apply -f -

# Undeploy the catalog from a Kubernetes cluster.
.PHONY: undeploy-catalog
undeploy-catalog: $(KUSTOMIZE) ## Undeploy controller from the K8s cluster specified in ~/.kube/config using OLM catalog image.
	$(KUSTOMIZE) build config/deploy/olm | kubectl delete -f -
