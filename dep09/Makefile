sshec2:
	ssh -i terraform/private-key.pem ubuntu@$$(terraform -chdir=terraform output -raw public_dns)