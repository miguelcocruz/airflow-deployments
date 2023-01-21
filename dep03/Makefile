sshec2-airflow:
	ssh -i terraform/ec2-ssh-private-key.pem ubuntu@$$(terraform -chdir=terraform output -raw ec2_airflow_public_dns_name)

sshec2-metastore:
	ssh -i terraform/ec2-ssh-private-key.pem ubuntu@$$(terraform -chdir=terraform output -raw ec2_metastore_public_dns_name)