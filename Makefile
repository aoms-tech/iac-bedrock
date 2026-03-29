ENV ?= dev
PROFILE ?= bedrock-workload
TF := AWS_PROFILE=$(PROFILE) terraform

.PHONY: init workspace-new workspace-list plan apply destroy

init:
	$(TF) init -backend-config=backend.hcl

workspace-new:
	$(TF) workspace new $(ENV)

workspace-list:
	$(TF) workspace list

plan:
	$(TF) workspace select $(ENV)
	$(TF) plan -var-file=environments/$(ENV)/terraform.tfvars

apply:
	$(TF) workspace select $(ENV)
	$(TF) apply -var-file=environments/$(ENV)/terraform.tfvars

destroy:
	$(TF) workspace select $(ENV)
	$(TF) destroy -var-file=environments/$(ENV)/terraform.tfvars
