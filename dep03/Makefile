sshec2:
	ssh -i terraform/ec2-ssh-private-key.pem ubuntu@$$(terraform -chdir=terraform output -raw public_ec2_public_ip)