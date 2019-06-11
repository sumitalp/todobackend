# Project Variables
PROJECT_NAME ?= todobackend # Retreive from env variable otherwise todobackend
ORG_NAME ?= ahsankhan
REPO_NAME ?= todobackend

# File names
DEV_COMPOSE_FILE := docker/dev/docker-compose-v2.yml
REL_COMPOSE_FILE := docker/release/docker-compose-v2.yml

# Docker Compose Project Names
REL_PROJECT := $(PROJECT_NAME)$(BUILD_ID)
DEV_PROJECT := $(REL_PROJECT:%=%dev) # Concat 'dev' string with REL_PROJECT

# Application service name - must match Docker Compose release specification application service name
APP_SERVICE_NAME := app

# Check and Inspect logic
INSPECT := $$(docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
	if [[ $(INSPECT) -ne 0 ]];\
	then exit $(INSPECT); fi' VALUE

# Use these settings to specify a custom Docker registry
DOCKER_REGISTRY ?= docker.io

# Get container id of application service container
APP_CONTAINER_ID := $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))

# Getting image id of application service
IMAGE_ID := $$(docker inspect -f '{{ .Image }}' $(APP_CONTAINER_ID))

# Build tag expression - can be used to evaluate a shell expression at runtime
BUILD_TAG_EXPRESSION ?= date -u +%Y%m%d%H%M%S

# Execute shell expression
BUILD_EXPRESSION := $(shell $(BUILD_TAG_EXPRESSION))

# Build tag - defaults to BUILD_EXPRESSION if not defined
BUILD_TAG ?= $(BUILD_EXPRESSION)

# WARNING: Set DOCKER_REGISTRY_AUTH to empty for Docker Hub
# Set DOCKER_REGISTRY_AUTH to auth endpoint for private Docker registry
DOCKER_REGISTRY_AUTH ?=

# Extract tag arguments
ifeq (tag,$(firstword $(MAKECMDGOALS))) # Inside we must put spaces rather than tab
	# wordlist function iterate from position 2 to length of arguments
	# words function counts the arguments length
    TAG_ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
    ifeq ($(TAG_ARGS),)
        $(error You must specify a tag)
    endif
	# below line with eval if the command is, `make tag 0.1 latest`
	# then it'll not interpret 0.1 latest as make target files
    $(eval $(TAG_ARGS):;@:)
endif

# Extract build tag arguments
ifeq (buildtag,$(firstword $(MAKECMDGOALS)))
	# wordlist function iterate from position 2 to length of arguments
	# words function counts the arguments length
    BUILDTAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
    ifeq ($(BUILDTAG_ARGS),)
        $(error You must specify a tag)
    endif
	# below line with eval if the command is, `make buildtag 0.1 latest`
	# then it'll not interpret 0.1 latest as make target files
    $(eval $(BUILDTAG_ARGS):;@:)
endif

.PHONY: test build release clean tag buildtag login logout publish

test:
	${INFO} "Creating external cache volume..."
	@ docker volume create --name cache
	${INFO} "Pulling latest images for consistency..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) pull
	${INFO} "Building images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build --pull test
	${INFO} "Ensuring database is ready..."
	# Here we use run --rm rather than up because we don't have any dependencies of that container
	# Such as, we don't need to copy anything. run --rm checks if there is any error occurs or not and then 
	# removes (clean up) the container
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	${INFO} "Running tests..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test
	${INFO} "Testing complete"

build:
	${INFO} "Creating builder image..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build builder
	${INFO} "Building application artifacts..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	${INFO} "Copying artifacts to target folder..."
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	${INFO} "Build complete"

release:
	${INFO} "Pulling latest images for consistency..."
	# Pull todobackend-specs image because we already has pulled todobackend-base image in `test` section
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) pull test 
	${INFO} "Building images..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build app
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build --pull nginx
	${INFO} "Ensuring database is ready..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm agent
	${INFO} "Collecting static files..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	${INFO} "Running database migrations..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	${INFO} "Running acceptance tests..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
	@ docker cp $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(REL_PROJECT) $(REL_COMPOSE_FILE) test
	${INFO} "Acceptance testing complete"

clean:
	${INFO} "Destroying development environment..." 
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) down -v # @ symbol is used to suppress which command is executed
	${INFO} "Destroying release environment..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) down -v
	${INFO} "Removing dangling images..."
	@ docker images -q -f dangling=true -f label=application=$(REPO_NAME) | xargs -I ARGS docker rmi -f ARGS
	${INFO} "Clean complete"

tag:
	${INFO} "Tagging release image with tags $(TAG_ARGS)..."
	@ $(foreach tag,$(TAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)
	${INFO} "Tagging complete"

buildtag:
	${INFO} "Tagging release image with suffix $(BUILD_TAG) and build tags $(BUILDTAG_ARGS)..."
	@ $(foreach tag,$(BUILDTAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag).$(BUILD_TAG);)
	${INFO} "Tagging complete"

login:
	${INFO} "Logging in to Docker registry $(DOCKER_REGISTRY)..."
	@ docker login -u $(DOCKER_USER) -p $(DOCKER_PASSWORD) $(DOCKER_REGISTRY_AUTH)
	${INFO} "Logged in to Docker registry $(DOCKER_REGISTRY)"

logout:
	${INFO} "Logging out to Docker registry $(DOCKER_REGISTRY)..."
	@ docker logout
	${INFO} "Logged out to Docker registry $(DOCKER_REGISTRY)"

publish:
	${INFO} "Publishing release image $(IMAGE_ID) to $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)..."
	$(foreach tag,$(shell echo $(REPO_EXPR)), docker push $(tag);)
	${INFO} "Publish complete"

%:
	@:

# Introspect repository tag
REPO_EXPR := $$(docker inspect -f '{{range .RepoTags}}{{.}} {{end}}' $(eval $(IMAGE_ID)) | grep -oh "$(REPO_FILTER)" | xargs)

# Repository Filter
ifeq ($(DOCKER_REGISTRY), docker.io)
    REPO_FILTER := $(ORG_NAME)/$(REPO_NAME)[^[:space:]]*
else
    REPO_FILTER := $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)[^[:space:]]*
endif

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell Functions
INFO := @bash -c '\
	printf $(YELLOW); \
	echo "=> $$1"; \
	printf $(NC)' VALUE