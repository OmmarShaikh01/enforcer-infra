# =====================================================================================================================
# VARS
# =====================================================================================================================
.DEFAULT_GOAL := help

ROOT_DIR  := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL     := /bin/bash
ENV       ?= PROD
DOCKER    ?= docker
KUBECTL   ?= kubectl
KUSTOMIZE ?= kustomize
HELM      ?= helm

# =====================================================================================================================
# TERRAFORM
# =====================================================================================================================
.PHONY: tf-init tf-format install-crd tf-destroy tf-apply tf-apply-replace tf-plan tf-dev-port

install-crd: ## Install CRDs
	 $(KUBECTL) apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml

tf-init: install-crd ## Init Terraform
	@case $(ENV) in \
		dev|DEV) DIR=environments/dev ;; \
		prod|PROD) DIR=environments/prod ;; \
		*) echo "Error: ENV must be DEV or PROD"; exit 1 ;; \
	esac; \
	cd $(ROOT_DIR)$$DIR; \
	terraform init;

tf-format: ## Format Terraform
	cd $(ROOT_DIR); \
	terraform fmt -recursive;

tf-destroy: ## Destroy Terraform
	@case $(ENV) in \
		dev|DEV) DIR=environments/dev ;; \
		prod|PROD) DIR=environments/prod ;; \
		*) echo "Error: ENV must be DEV or PROD"; exit 1 ;; \
	esac; \
	cd $(ROOT_DIR)$$DIR; \
	terraform apply -auto-approve -var-file="environment.tfvars" -destroy;

tf-apply: ## Deploy Terraform
	@case $(ENV) in \
		dev|DEV) DIR=environments/dev ;; \
		prod|PROD) DIR=environments/prod ;; \
		*) echo "Error: ENV must be DEV or PROD"; exit 1 ;; \
	esac; \
	cd $(ROOT_DIR)$$DIR; \
	terraform apply -auto-approve -var-file="environment.tfvars"

tf-apply-replace: ## Deploy Terraform Relace, Assets
	@case $(ENV) in \
		dev|DEV) DIR=environments/dev ;; \
		prod|PROD) DIR=environments/prod ;; \
		*) echo "Error: ENV must be DEV or PROD"; exit 1 ;; \
	esac; \
	cd $(ROOT_DIR)$$DIR; \
	terraform apply -auto-approve -var-file="environment.tfvars" -replace $(ASSET)

tf-plan: ## Destroy Terraform
	@case $(ENV) in \
		dev|DEV) DIR=environments/dev ;; \
		prod|PROD) DIR=environments/prod ;; \
		*) echo "Error: ENV must be DEV or PROD"; exit 1 ;; \
	esac; \
	cd $(ROOT_DIR)$$DIR; \
	terraform plan -var-file="environment.tfvars" -out ".tfplan"; \
	terraform show -var-file="environment.tfvars" -json ".tfplan" | jq > .tfplan.json; \
	rm .tfplan

tf-dev-port: ## Forward Datastore plane traffic
	kubectl port-forward --namespace enforcer service/enforcer-postgres-srvc 8100:5432
	kubectl port-forward --namespace enforcer service/enforcer-redis-srvc 8090:6379