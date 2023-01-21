sshec2:
	ssh -i terraform/ec2-ssh-private-key.pem ubuntu@$$(terraform -chdir=terraform output -raw ec2_public_dns_name)