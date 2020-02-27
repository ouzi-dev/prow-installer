include install.mk

DRY_RUN ?= true
DIRECTORY = $(sort $(dir $(wildcard */.)))

HELM_PLUGIN_DIFF_URL := https://github.com/databus23/helm-diff
HELM_PLUGIN_DIFF_VERSION := v3.0.0-rc.7

.PHONY: init
init: 
	helm plugin install $(HELM_PLUGIN_DIFF_URL) --version $(HELM_PLUGIN_DIFF_VERSION) || echo "Plugin already installed - nothing to do"
	helm repo add stable https://kubernetes-charts.storage.googleapis.com/
	helm repo add jetstack https://charts.jetstack.io
	helm repo add estafette https://helm.estafette.io
	helm repo update

.PHONY: all-deploy
deploy: $(addsuffix -deploy,$($*DIRECTORY:/=))

%-deploy: $($*DIRECTORY:/=)
	@echo "*Deploying $*"
	@$(MAKE) FOLDER=$* install
	@echo ""

.PHONY: all-dry-run
all-dry-run: $(addsuffix -dry-run,$($*DIRECTORY:/=))

%-dry-run: $($*DIRECTORY:/=)
	@echo ** dry-run target $* **
	@$(MAKE) -C $* dry-run

%-delete: $($*DIRECTORY:/=)
	@echo ** delete target $* **
	@$(MAKE) -C $* delete