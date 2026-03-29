ENV ?= dev
PROFILE ?= bedrock-workload
TF := AWS_PROFILE=$(PROFILE) terraform

.PHONY: init plan apply destroy workspace-list

init:
	$(TF) init -backend-config=backend.hcl

plan:
	$(TF) workspace select $(ENV)
	$(TF) plan -var-file=environments/$(ENV)/terraform.tfvars

apply:
	$(TF) workspace select $(ENV)
	$(TF) apply -var-file=environments/$(ENV)/terraform.tfvars

destroy:
	$(TF) workspace select $(ENV)
	$(TF) destroy -var-file=environments/$(ENV)/terraform.tfvars

workspace-list:
	$(TF) workspace list
