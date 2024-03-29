SHELL = /usr/bin/env bash -eo pipefail

DRY_RUN ?= false
VALIDATE ?= false

KUBEVAL_OPTS ?= --strict --kubernetes-version 1.21.0 --ignore-missing-schemas

VALUES ?= values.yaml
K8SAPI_DEPRECATED_MAPPINGS ?= k8sapi_deprecated_mappings.yaml


# We need bash version 5 and above
BASH_MIN_MAJOR_VERSION = 5
ifeq ($(shell test $$BASH_VERSINFO -lt $(BASH_MIN_MAJOR_VERSION); echo $$?),0)
$(error Requires bash version $(BASH_MIN_MAJOR_VERSION) and above)
endif

# We need helm version 3 and above
HELM_MIN_MAJOR_VERSION = 3
ifeq ($(shell test $(shell helm version --short | cut -d'+' -f1 | tr -d v | cut -d'.' -f1) -lt $(HELM_MIN_MAJOR_VERSION); echo $$?),0)
$(error Requires helm version $(HELM_MIN_MAJOR_VERSION) and above)
endif

# We need yq version 3 and above
YQ_MIN_MAJOR_VERSION = 3
ifeq ($(shell test $(shell yq --version | cut -d' ' -f3 | cut -d'.' -f1) -lt $(YQ_MIN_MAJOR_VERSION); echo $$?),0)
$(error Requires yq version $(YQ_MIN_MAJOR_VERSION) and above)
endif

.PHONY: install
install:
ifneq ($(wildcard $(FOLDER)/00-manifests/.*),)
	@$(MAKE) \
		FOLDER=$(FOLDER) \
		SUBFOLDER=00-manifests \
		install-manifests-gotpl
endif
ifneq ($(wildcard $(FOLDER)/01-helm/.*),)
	@if [[ "$(call get_package_value,helm.version)" == "null" ]]; then \
		$(MAKE) \
			FOLDER=$(FOLDER) \
			NAME=$(call get_package_value,helm.name) \
			CHART=$(call get_package_value,helm.chart) \
			NAMESPACE=$(call get_package_value,namespace) \
			SUBFOLDER=01-helm \
			install-helm-chart-url; \
	else \
		$(MAKE) \
			FOLDER=$(FOLDER) \
			NAME=$(call get_package_value,helm.name) \
			CHART=$(call get_package_value,helm.chart) \
			VERSION=$(call get_package_value,helm.version) \
			NAMESPACE=$(call get_package_value,namespace) \
			SUBFOLDER=01-helm \
			install-helm-chart; \
	fi
endif
ifneq ($(wildcard $(FOLDER)/02-manifests/.*),)
	@$(MAKE) \
					FOLDER=$(FOLDER) \
					SUBFOLDER=02-manifests \
					install-manifests-gotpl
endif

.PHONY: install-manifests-gotpl
install-manifests-gotpl:
	@gotpl \
	$(FOLDER)/values.yaml \
	--values $(VALUES) \
	$(SET_VALUES) \
	--strict > $(FOLDER)/.values.yaml
ifeq ($(VALIDATE),true)
	@echo **Validating $(FOLDER)/${SUBFOLDER} \(kubeval\)
	@gotpl \
		$(FOLDER)/${SUBFOLDER} \
		--values $(VALUES) \
		--values $(FOLDER)/.values.yaml \
		$(SET_VALUES) \
		--strict \
		$(EXTRA_ARGS) \
		| kubeval $(KUBEVAL_OPTS)
endif
ifeq ($(DRY_RUN),true)
	@echo **Applying $(FOLDER)/${SUBFOLDER} \(Dry Run\)
	@gotpl \
		$(FOLDER)/${SUBFOLDER} \
		--values $(VALUES) \
		--values $(FOLDER)/.values.yaml \
		$(SET_VALUES) \
		--strict \
		$(EXTRA_ARGS) \
		| kubectl apply --dry-run $(KUBECTL_ARGS) -f -
else ifeq ($(DRY_RUN),false)
	@echo **Applying $(FOLDER)/${SUBFOLDER}
	@gotpl \
		$(FOLDER)/${SUBFOLDER} \
		--values $(VALUES) \
		--values $(FOLDER)/.values.yaml \
		$(SET_VALUES) \
		--strict \
		$(EXTRA_ARGS) \
		| kubectl apply $(KUBECTL_ARGS) -f -
endif
	# @rm $(FOLDER)/.values.yaml

.PHONY: install-helm-chart
install-helm-chart:
	@gotpl \
	$(FOLDER)/${SUBFOLDER}/values.yaml \
	--values $(VALUES) \
	--values $(FOLDER)/values.yaml \
	$(SET_VALUES) \
	--strict > $(FOLDER)/${SUBFOLDER}/.values.yaml
ifeq ($(VALIDATE),true)
	@echo **Validating helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm template \
		$(NAME) \
		$(CHART) \
		--version $(VERSION) \
		--no-hooks \
		--namespace $(NAMESPACE) \
		$(SET_VALUES) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml \
		| kubeval $(KUBEVAL_OPTS)	
endif
ifeq ($(DRY_RUN),true)
	@echo **Migrating \(Dry Run\) deprecated or removed Kubernetes APIs in Helm storage
	@helm mapkubeapis --namespace $(NAMESPACE) --mapfile $(K8SAPI_DEPRECATED_MAPPINGS) --dry-run $(NAME)
	@echo **Upgrading \(Dry Run\) helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm diff upgrade \
		$(NAME) \
		$(CHART) \
		--version $(VERSION) \
		--no-hooks \
		--namespace $(NAMESPACE) \
		--allow-unreleased \
		$(HELM_EXTRA_ARGS) \
		$(SET_VALUES) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml
else ifeq ($(DRY_RUN),false)
	@echo **Migrating deprecated or removed Kubernetes APIs in Helm storage
	@helm mapkubeapis --namespace $(NAMESPACE) --mapfile $(K8SAPI_DEPRECATED_MAPPINGS) $(NAME) || true
	@echo **Upgrading helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm upgrade \
		$(NAME) \
		$(CHART) \
		--version $(VERSION) \
		--install \
		--wait \
		--namespace $(NAMESPACE) \
		$(HELM_EXTRA_ARGS) \
		$(SET_VALUES) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml
endif
	# @rm $(FOLDER)/$(SUBFOLDER)/.values.yaml

.PHONY: install-helm-chart-url
install-helm-chart-url:
	@gotpl \
	$(FOLDER)/${SUBFOLDER}/values.yaml \
	--values $(VALUES) \
	--values $(FOLDER)/values.yaml \
	$(SET_VALUES) \
	--strict > $(FOLDER)/${SUBFOLDER}/.values.yaml
ifeq ($(VALIDATE),true)
	@echo **Validating helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm template \
		$(NAME) \
		$(CHART) \
		--no-hooks \
		--namespace $(NAMESPACE) \
		$(HELM_EXTRA_ARGS) \
		$(SET_VALUES) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml	\
		| kubeval $(KUBEVAL_OPTS)	
endif
ifeq ($(DRY_RUN),true)
	@echo **Migrating \(Dry Run\) deprecated or removed Kubernetes APIs in Helm storage
	@helm mapkubeapis --namespace $(NAMESPACE) --mapfile $(K8SAPI_DEPRECATED_MAPPINGS) --dry-run $(NAME)
	@echo **Upgrading \(Dry Run\) helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm diff upgrade \
		$(NAME) \
		$(CHART) \
		--no-hooks \
		--namespace $(NAMESPACE) \
		--allow-unreleased \
		$(HELM_EXTRA_ARGS) \
		$(SET_VALUES) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml 		
else ifeq ($(DRY_RUN),false)
	@echo **Migrating deprecated or removed Kubernetes APIs in Helm storage
	@helm mapkubeapis --namespace $(NAMESPACE) --mapfile $(K8SAPI_DEPRECATED_MAPPINGS) $(NAME) || true
	@echo **Upgrading helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm upgrade \
		$(NAME) \
		$(CHART) \
		--install \
		--wait \
		--namespace $(NAMESPACE) \
		$(HELM_EXTRA_ARGS) \
		$(SET_VALUES) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml 	
endif
	# @rm $(FOLDER)/$(SUBFOLDER)/.values.yaml 




# get main value
# $(call get_main_value,global.email) 
get_main_value = $(shell cat values.yaml | yq r - $(call get_clean_name,$(FOLDER)).$(1) )

# get package value
# $(call get_package_value,namespace) 
get_package_value = $(shell cat $(FOLDER)/values.yaml | yq r - $(call get_clean_name,$(FOLDER)).$(1) )

# get folder name without the ##- part
# $(call get_clean_name,00-blah) 
get_clean_name = $(word 2,$(subst -, ,$1))

# check if two string are equal
# $(call eq,alex,mike) 
eq = $(and $(findstring $(1),$(2)),$(findstring $(2),$(1)))
