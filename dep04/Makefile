push-docker-image:
	aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $$(terraform -chdir=terraform/ecr output -raw ecr_url) && \
	docker build -t lgmrepo . && \
	docker tag lgmrepo:latest $$(terraform -chdir=terraform/ecr output -raw ecr_url):latest && \
	docker push $$(terraform -chdir=terraform/ecr output -raw ecr_url):latest


