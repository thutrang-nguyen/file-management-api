build:
	docker build --rm -t ${DOCKER_REGISTRY}${PROJECT_NAME}:${BRANCH_NAME} .
push:
	$(aws ecr get-login --region ${AWS_DEFAULT_REGION} --no-include-email)
	docker push $(DOCKER_REGISTRY)${PROJECT_NAME}:$(BRANCH_NAME)
run:
	docker run -d --name=$(PROJECT_NAME) \
	--env-file=.env -p 5000:5000 \
	$(DOCKER_REGISTRY)$(PROJECT_NAME):$(BRANCH_NAME)
	docker inspect $(PROJECT_NAME) --format '{{ .NetworkSettings.IPAddress }}' 
clean:
	docker rm -f $(PROJECT_NAME)
