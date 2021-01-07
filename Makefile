include install.mk

DIRECTORY = $(notdir $(sort $(wildcard packages/*)))
VALUES ?= values.yaml

DIST_DIR = .dist/
DIST_VERSION ?= canary
RELEASE = $(DIST_DIR)/prow-installer-$(DIST_VERSION).tar.gz

HELM_PLUGIN_DIFF_URL := https://github.com/databus23/helm-diff
HELM_PLUGIN_DIFF_VERSION := v3.0.0-rc.7

.PHONY: init
init: 
	helm plugin install $(HELM_PLUGIN_DIFF_URL) --version $(HELM_PLUGIN_DIFF_VERSION) || echo "Plugin already installed - nothing to do"
# plugin to handle deprecated apis
	helm plugin install https://github.com/hickeyma/helm-mapkubeapis || echo "Plugin already installed - nothing to do"
	helm repo add stable https://charts.helm.sh/stable
	helm repo add jetstack https://charts.jetstack.io
	helm repo add estafette https://helm.estafette.io
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update

.PHONY: deploy
deploy: $(addsuffix -deploy,$($*DIRECTORY:/=))

.PHONY: %-deploy
%-deploy:
	@echo "*Deploying package $*"
	@$(MAKE) FOLDER=packages/$* VALUES=$(VALUES) SET_VALUES=$(SET_VALUES) install

.PHONY: validate
validate: $(addsuffix -validate,$($*DIRECTORY:/=))

.PHONY: %-validate
%-validate:
	@echo "*Validating package $*"
	@$(MAKE) VALIDATE=true DRY_RUN= FOLDER=packages/$* VALUES=$(VALUES) SET_VALUES=$(SET_VALUES) install

package: 
	@echo Creating package...
	@mkdir -p $(DIST_DIR)
	@tar -zcf $(RELEASE) packages/ Makefile install.mk k8sapi_deprecated_mappings.yaml LICENSE 
	@echo Creating package...Done $(RELEASE)

.PHONY: semantic-release
semantic-release:
	npm ci
	npx semantic-release

.PHONY: semantic-release-dry-run
semantic-release-dry-run:
	npm ci
	npx semantic-release -d

.PHONY: install-npm-check-updates
install-npm-check-updates:
	npm install npm-check-updates

.PHONY: update-npm-dependencies
update-npm-dependencies: install-npm-check-updates
	ncu -u
	npm install