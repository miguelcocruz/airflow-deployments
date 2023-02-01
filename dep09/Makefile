sshec2:
	ssh -i terraform/private-key.pem ubuntu@$$(terraform -chdir=terraform output -raw public_dns)

tfapply:
	terraform -chdir=terraform apply -var-file="env.tfvars"

tfdestroy:
	terraform -chdir=terraform destroy -var-file="env.tfvars"