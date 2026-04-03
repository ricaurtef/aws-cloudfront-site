SHELL := /bin/bash

.DEFAULT_GOAL := help

define USAGE
Usage: make TARGET_NAME

Targets:
  check       Check Terraform code formatting.
  checkov     Run Checkov security scan.
  chores      Run all maintenance tasks (check, document, format).
  document    Generate documentation for Terraform code.
  format      Format Terraform code.
  security    Run security scans (Checkov, Trivy).
  setup       Initialize the development environment.
  test        Run Terraform tests.
  tflint      Run TFLint to analyze Terraform code for potential issues.
  tflint_fix  Run TFLint with auto-fix (review changes before committing).
  trivy       Run Trivy security scan.
  validate    Validate Terraform configuration.
  help        Display this help message.
endef

.PHONY: help
help:; @$(info $(USAGE)) :

.PHONY: chores
chores: document format

.PHONY: check
check:
	@echo "Checking Terraform code formatting..."
	terraform fmt -check -recursive

.PHONY: document
document:
	@echo "Generating documentation for Terraform code..."
	terraform-docs --config .config/terraform-docs.yml .

.PHONY: format
format:
	@echo "Formatting Terraform code..."
	terraform fmt -recursive

.PHONY: security
security: checkov trivy

.PHONY: checkov
checkov:
	@echo "Running Checkov..."
	checkov --directory . --config-file .config/checkov.yml

.PHONY: trivy
trivy:
	@echo "Running Trivy..."
	trivy fs . --config .config/trivy.yaml

.PHONY: setup
setup:
	@for tool in terraform terraform-docs tflint checkov trivy pre-commit; do \
		command -v $$tool >/dev/null 2>&1 || { printf "Error: '$$tool' not found. See README.md for installation instructions.\n"; exit 1; }; \
	done
	@echo "Initializing development environment..."
	@pre-commit install --config .config/pre-commit-config.yml
	@tflint --init --config .config/tflint.hcl
	@terraform init -backend=false

.PHONY: test
test:
	@echo "Running Terraform tests..."
	# terraform test

.PHONY: tflint
tflint:
	@echo "Running TFLint..."
	tflint --config .config/tflint.hcl

.PHONY: tflint_fix
tflint_fix:
	@echo "Running TFLint with auto-fix..."
	@echo "[Warning] TFLint auto-fix isn't perfect. ALWAYS review changes before committing."
	tflint --init --config .config/tflint.hcl
	tflint --fix --config .config/tflint.hcl

.terraform:
	@echo "Initializing Terraform..."
	@terraform init -backend=false

.PHONY: validate
validate: .terraform
	@echo "Validating Terraform configuration..."
	terraform validate
