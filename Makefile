include install.mk

DRY_RUN ?= true
DIRECTORY = $(notdir $(wildcard packages/*))
VALUES ?= values.yaml

DIST_DIR = .dist/
DIST_VERSION ?= canary
RELEASE = $(DIST_DIR)/prow-installer-$(DIST_VERSION).tar.gz

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

.PHONY: %-deploy
%-deploy:
	@echo "*Deploying package $*"
	@$(MAKE) FOLDER=packages/$* VALUES=$(VALUES) SET_VALUES=$(SET_VALUES) install

package: 
	@echo Creating package...
	@mkdir -p $(DIST_DIR)
	@tar -zcf $(RELEASE) packages/ Makefile install.mk LICENSE
	@echo Creating package...Done $(RELEASE)

.PHONY: semantic-release
semantic-release:
	npm ci
	npx semantic-release

.PHONY: semantic-release-dry-run
semantic-release-dry-run:
	npm ci
	npx semantic-release -d