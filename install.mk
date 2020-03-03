DRY_RUN ?= true
VALUES ?= values.yaml

SHELL = /bin/bash -eo pipefail

.PHONY: install
install:
ifneq ($(wildcard $(FOLDER)/00-manifests/.*),)
	@$(MAKE) \
					FOLDER=$(FOLDER) \
					SUBFOLDER=00-manifests \
					install-manifests-gotpl
endif
ifneq ($(wildcard $(FOLDER)/01-helm/.*),)
	@if [ $(call get_package_value,helm.version) = "null" ]; then\
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
	--strict > $(FOLDER)/.values.yaml
ifeq ($(DRY_RUN),true)
	@echo **Applying $(FOLDER)/${SUBFOLDER} \(Dry Run\)
	@gotpl \
		$(FOLDER)/${SUBFOLDER} \
		--values $(VALUES) \
		--values $(FOLDER)/.values.yaml \
		--strict \
		$(EXTRA_ARGS) \
		| kubectl apply --dry-run $(KUBECTL_ARGS) -f -
else
	@echo **Applying $(FOLDER)/${SUBFOLDER}
	@gotpl \
		$(FOLDER)/${SUBFOLDER} \
		--values $(VALUES) \
		--values $(FOLDER)/.values.yaml \
		--strict \
		$(EXTRA_ARGS) \
		| kubectl apply $(KUBECTL_ARGS) -f -
endif
	@rm $(FOLDER)/.values.yaml

.PHONY: install-helm-chart
install-helm-chart:
	@gotpl \
	$(FOLDER)/${SUBFOLDER}/values.yaml \
	--values $(VALUES) \
	--values $(FOLDER)/values.yaml \
	--strict > $(FOLDER)/${SUBFOLDER}/.values.yaml
ifeq ($(DRY_RUN),true)
	@echo **Upgrading \(Dry Run\) helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm diff upgrade \
		$(NAME) \
		$(CHART) \
		--version $(VERSION) \
		--no-hooks \
		--namespace $(NAMESPACE) \
		--allow-unreleased \
		$(HELM_EXTRA_ARGS) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml
else
	@echo **Upgrading helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm upgrade \
		$(NAME) \
		$(CHART) \
		--version $(VERSION) \
		--install \
		--wait \
		--namespace $(NAMESPACE) \
		$(HELM_EXTRA_ARGS) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml
endif
	@rm $(FOLDER)/$(SUBFOLDER)/.values.yaml

.PHONY: install-helm-chart-url
install-helm-chart-url:
	@gotpl \
	$(FOLDER)/${SUBFOLDER}/values.yaml \
	--values $(VALUES) \
	--values $(FOLDER)/values.yaml \
	--strict > $(FOLDER)/${SUBFOLDER}/.values.yaml
ifeq ($(DRY_RUN),true)
	@echo **Upgrading \(Dry Run\) helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm diff upgrade \
		$(NAME) \
		$(CHART) \
		--no-hooks \
		--namespace $(NAMESPACE) \
		--allow-unreleased \
		$(HELM_EXTRA_ARGS) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml 		
else
	@echo **Upgrading helm chart $(CHART) $(NAME) $(VERSION) from $(FOLDER)/$(SUBFOLDER) in $(NAMESPACE)
	@helm upgrade \
		$(NAME) \
		$(CHART) \
		--install \
		--wait \
		--namespace $(NAMESPACE) \
		$(HELM_EXTRA_ARGS) \
		--values $(FOLDER)/$(SUBFOLDER)/.values.yaml 	
endif
	@rm $(FOLDER)/$(SUBFOLDER)/.values.yaml 




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
