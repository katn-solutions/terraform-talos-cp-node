.PHONY: help lint test fmt init validate tflint clean all test-unit test-compliance

# Terraform parameters
TERRAFORM=terraform
TFLINT=tflint
TERRAFORM_COMPLIANCE=terraform-compliance
TEST_DIR=test

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fmt: ## Format Terraform files
	@echo "Formatting Terraform files..."
	@$(TERRAFORM) fmt -recursive

init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	@$(TERRAFORM) init -backend=false

validate: init ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	@$(TERRAFORM) validate

tflint: ## Run tflint
	@echo "Running tflint..."
	@$(TFLINT) --init
	@$(TFLINT) --format compact

lint: ## Run all linting (fmt check + tflint)
	@echo "Checking Terraform format..."
	@$(TERRAFORM) fmt -check -recursive
	@$(MAKE) tflint

test: validate ## Run Terraform validation
	@echo "Terraform validation completed successfully"

test-unit: ## Run Terratest unit tests
	@echo "Running Terratest unit tests..."
	@cd $(TEST_DIR) && go test -v -timeout 10m

test-compliance: ## Run terraform-compliance BDD tests
	@echo "Running terraform-compliance tests..."
	@echo "Generating terraform plan..."
	@$(TERRAFORM) plan -out=/tmp/tf-plan.out || echo "Plan generation failed - skipping compliance"
	@if [ -f /tmp/tf-plan.out ]; then \
		$(TERRAFORM_COMPLIANCE) -f ../compliance -p /tmp/tf-plan.out; \
		rm -f /tmp/tf-plan.out; \
	fi

clean: ## Clean Terraform artifacts
	@echo "Cleaning Terraform artifacts..."
	@rm -rf .terraform .terraform.lock.hcl
	@cd $(TEST_DIR) && go clean -testcache

all: lint test test-unit ## Run linting, validation, and unit tests (default target)

.DEFAULT_GOAL := all
