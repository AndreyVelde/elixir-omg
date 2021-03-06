MAKEFLAGS += --silent
OVERRIDING_START ?= foreground
SNAPSHOT ?= SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_20
BAREBUILD_ENV ?= dev
help:
	@echo "Dont Fear the Makefile"
	@echo ""
	@echo "PRE-LUMPHINI"
	@echo "------------------"
	@echo
	@echo "If you want to connect to an existing network (Pre-Lumphini) with a Watcher \c"
	@echo "and validate transactions. Run:"
	@echo "  - \`make start-pre-lumphini-watcher\` \c"
	@echo ""
	@echo
	@echo "DOCKER DEVELOPMENT"
	@echo "------------------"
	@echo ""
	@echo "  - \`make docker-start-cluster\`: start everything for you, but if there are no local images \c"
	@echo "for Watcher and Child chain tagged with latest they will get pulled from our repository."
	@echo ""
	@echo "  - \`make docker-start-cluster-with-infura\`: start everything but connect to Infura \c"
	@echo "instead of your own local geth network. Note: you will need to configure the environment \c"
	@echo "variables defined in docker-compose-infura.yml"
	@echo ""
	@echo "  - \`make docker-watcher && make docker-watcher_info && make docker-child_chain\`: \c"
	@echo "use your own image containers for Watcher, Watcher Info and Child Chain"
	@echo ""
	@echo "  - \`make docker-update-watcher\`, \`make docker-update-watcher_info\` or \c"
	@echo "\`make docker-update-child_chain\`: replaces containers with your code changes\c"
	@echo "for rapid development."
	@echo ""
	@echo "  - \`make docker-nuke\`: wipe docker clean, including containers, images, networks \c"
	@echo "and build cache."
	@echo ""
	@echo "  - \`make docker-remote-watcher\`: remote console (IEx-style) into the watcher application."
	@echo ""
	@echo "  - \`make docker-remote-watcher_info\`: remote console (IEx-style) into the \c"
	@echo "watcher_info application."
	@echo ""
	@echo "  - \`make docker-remote-childchain\`: remote console (IEx-style) into the childchain application."
	@echo ""
	@echo "BARE METAL DEVELOPMENT"
	@echo "----------------------"
	@echo
	@echo "This presumes you want to run geth and postgres as containers \c"
	@echo "but Watcher and Child Chain bare metal. You will need four terminal windows."
	@echo ""
	@echo "1. In the first one, start geth, postgres:"
	@echo "    make start-services"
	@echo ""
	@echo "2. In the second terminal window, run:"
	@echo "    make start-child_chain"
	@echo ""
	@echo "3. In the third terminal window, run:"
	@echo "    make start-watcher"
	@echo ""
	@echo ""
	@echo "4. In the fourth terminal window, run:"
	@echo "    make start-watcher_info"
	@echo ""
	@echo "5. Wait until they all boot. And run in the fifth terminal window:"
	@echo "    make get-alarms"
	@echo ""
	@echo "If you want to attach yourself to running services, use:"
	@echo "    make remote-child_chain"
	@echo "or"
	@echo "    make remote-watcher"
	@echo ""
	@echo "or"
	@echo "    make remote-watcher_info"
	@echo ""
	@echo "MISCELLANEOUS"
	@echo "-------------"
	@echo "  - \`make diagnostics\`: generate comprehensive diagnostics info for troubleshooting"
	@echo "  - \`make list\`: list all available make targets"
	@echo ""

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

all: clean build-child_chain-prod build-watcher-prod build-watcher_info-prod

WATCHER_IMAGE_NAME      ?= "omisego/watcher:latest"
WATCHER_INFO_IMAGE_NAME ?= "omisego/watcher_info:latest"
CHILD_CHAIN_IMAGE_NAME  ?= "omisego/child_chain:latest"

IMAGE_BUILDER   ?= "omisegoimages/elixir-omg-builder:stable-20200104"
IMAGE_BUILD_DIR ?= $(PWD)

ENV_DEV         ?= env MIX_ENV=dev
ENV_TEST        ?= env MIX_ENV=test
ENV_PROD        ?= env MIX_ENV=prod

WATCHER_PORT ?= 7434
WATCHER_INFO_PORT ?= 7534

#
# Setting-up
#

deps: deps-elixir-omg

deps-elixir-omg:
	HEX_HTTP_TIMEOUT=120 mix deps.get

.PHONY: deps deps-elixir-omg

#
# Cleaning
#

clean: clean-elixir-omg

clean-elixir-omg:
	rm -rf _build/*
	rm -rf deps/*


.PHONY: clean clean-elixir-omg

#
# Linting
#

format:
	mix format

check-format:
	mix format --check-formatted 2>&1

check-credo:
	$(ENV_TEST) mix credo 2>&1

check-dialyzer:
	$(ENV_TEST) mix dialyzer --halt-exit-status 2>&1

.PHONY: format check-format check-credo

#
# Building
#


build-child_chain-prod: deps-elixir-omg
	$(ENV_PROD) mix do compile, distillery.release --name child_chain --verbose

build-child_chain-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, distillery.release dev --name child_chain --verbose

build-watcher-prod: deps-elixir-omg
	$(ENV_PROD) mix do compile, distillery.release --name watcher --verbose

build-watcher-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher --verbose

build-watcher_info-prod: deps-elixir-omg
	$(ENV_PROD) mix do compile, distillery.release --name watcher_info --verbose

build-watcher_info-dev: deps-elixir-omg
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher_info --verbose

build-test: deps-elixir-omg
	$(ENV_TEST) mix compile

.PHONY: build-prod build-dev build-test

#
# Testing
#

# get the SNAPSHOT url from the snapshots file based on the SNAPSHOT env value
# untar the snapshot and fetch values from the files in build dir that came from plasma-deployer
# put these values into an localchain_contract_addresses.env via the script in bin
# localchain_contract_addresses.env is used by docker, exunit tests and end2end tests

init_test:
	mkdir data/ || true && \
	rm -rf data/* || true && \
	URL=$$(grep "^$(SNAPSHOT)" snapshots.env | cut -d'=' -f2-) && \
	wget $$URL -O data/snapshot.tar.gz && \
	cd data && \
	tar --strip-components 1 -zxvf snapshot.tar.gz data/geth && \
	tar --exclude=data/* -xvzf snapshot.tar.gz && \
	AUTHORITY_ADDRESS=$$(cat plasma-contracts/build/authority_address) && \
	ETH_VAULT=$$(cat plasma-contracts/build/eth_vault) && \
	ERC20_VAULT=$$(cat plasma-contracts/build/erc20_vault) && \
	PAYMENT_EXIT_GAME=$$(cat plasma-contracts/build/payment_exit_game) && \
	PLASMA_FRAMEWORK_TX_HASH=$$(cat plasma-contracts/build/plasma_framework_tx_hash) && \
	PLASMA_FRAMEWORK=$$(cat plasma-contracts/build/plasma_framework) && \
	PAYMENT_EIP712_LIBMOCK=$$(cat plasma-contracts/build/paymentEip712LibMock) && \
	MERKLE_WRAPPER=$$(cat plasma-contracts/build/merkleWrapper) && \
	ERC20_MINTABLE=$$(cat plasma-contracts/build/erc20Mintable) && \
	sh ../bin/generate-localchain-env AUTHORITY_ADDRESS=$$AUTHORITY_ADDRESS ETH_VAULT=$$ETH_VAULT \
	ERC20_VAULT=$$ERC20_VAULT PAYMENT_EXIT_GAME=$$PAYMENT_EXIT_GAME \
	PLASMA_FRAMEWORK_TX_HASH=$$PLASMA_FRAMEWORK_TX_HASH PLASMA_FRAMEWORK=$$PLASMA_FRAMEWORK \
	PAYMENT_EIP712_LIBMOCK=$$PAYMENT_EIP712_LIBMOCK MERKLE_WRAPPER=$$MERKLE_WRAPPER ERC20_MINTABLE=$$ERC20_MINTABLE

test:
	mix test --include test --exclude common --exclude watcher --exclude watcher_info --exclude child_chain

test-watcher:
	mix test --include watcher --exclude watcher_info --exclude child_chain --exclude common --exclude test

test-watcher_info:
	mix test --include watcher_info --exclude watcher --exclude child_chain --exclude common --exclude test

test-common:
	mix test --include common --exclude child_chain --exclude watcher --exclude watcher_info --exclude test

test-child_chain:
	mix test --include child_chain --exclude common --exclude watcher  --exclude watcher_info --exclude test

#
# Documentation
#
changelog:
	github_changelog_generator -u omisego -p elixir-omg

.PHONY: changelog

###
start-pre-lumphini-watcher:
	docker-compose -f docker-compose-watcher.yml up
###

#
# Docker
#
docker-child_chain-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && make build-child_chain-prod"

docker-watcher-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && make build-watcher-prod"

docker-watcher_info-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v $(IMAGE_BUILD_DIR)/deps:/app/deps \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && make build-watcher_info-prod"

docker-child_chain-build:
	docker build -f Dockerfile.child_chain \
		--build-arg release_version=$$(cat $(PWD)/VERSION)+$$(git rev-parse --short=7 HEAD) \
		--cache-from $(CHILD_CHAIN_IMAGE_NAME) \
		-t $(CHILD_CHAIN_IMAGE_NAME) \
		.

docker-watcher-build:
	docker build -f Dockerfile.watcher \
		--build-arg release_version=$$(cat $(PWD)/VERSION)+$$(git rev-parse --short=7 HEAD) \
		--cache-from $(WATCHER_IMAGE_NAME) \
		-t $(WATCHER_IMAGE_NAME) \
		.

docker-watcher_info-build:
	docker build -f Dockerfile.watcher_info \
		--build-arg release_version=$$(cat $(PWD)/VERSION)+$$(git rev-parse --short=7 HEAD) \
		--cache-from $(WATCHER_INFO_IMAGE_NAME) \
		-t $(WATCHER_INFO_IMAGE_NAME) \
		.

docker-watcher: docker-watcher-prod docker-watcher-build
docker-watcher_info: docker-watcher_info-prod docker-watcher_info-build
docker-child_chain: docker-child_chain-prod docker-child_chain-build

docker-push: docker
	docker push $(CHILD_CHAIN_IMAGE_NAME)
	docker push $(WATCHER_IMAGE_NAME)
	docker push $(WATCHER_INFO_IMAGE_NAME)

###OTHER
docker-start-cluster:
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init_test && \
	docker-compose build --no-cache && docker-compose up

docker-stop-cluster:
	docker-compose down

docker-update-watcher:
	docker stop elixir-omg_watcher_1
	$(MAKE) docker-watcher
	docker-compose up watcher

docker-update-watcher_info:
	docker stop elixir-omg_watcher_info_1
	$(MAKE) docker-watcher_info
	docker-compose up watcher_info

docker-update-child_chain:
	docker stop elixir-omg_childchain_1
	$(MAKE) docker-child_chain
	docker-compose up childchain

docker-start-cluster-with-infura:
	if [ -f ./docker-compose.override.yml ]; then \
		docker-compose -f docker-compose.yml -f docker-compose-infura.yml -f docker-compose.override.yml up; \
	else \
		echo "Starting infura requires overriding docker-compose-infura.yml values in a docker-compose.override.yml"; \
	fi

docker-start-cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up watcher watcher_info childchain

docker-stop-cluster-with-datadog:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

docker-nuke:
	docker-compose down --remove-orphans
	docker system prune --all

docker-remote-watcher:
	docker-compose exec watcher /watcher_entrypoint bin/watcher remote_console

docker-remote-watcher_info:
	docker-compose exec watcher_info /watcher_info_entrypoint bin/watcher_info remote_console

docker-remote-childchain:
	docker-compose exec childchain /child_chain_entrypoint bin/child_chain remote_console

.PHONY: docker-nuke docker-remote-watcher docker-remote-watcher_info docker-remote-childchain

###
### barebone stuff
###
start-services:
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init_test && \
	docker-compose up geth postgres

start-child_chain:
	set -e; . ./bin/variables; \
	echo "Building Child Chain" && \
	make build-child_chain-${BAREBUILD_ENV} && \
	rm -f ./_build/${BAREBUILD_ENV}/rel/child_chain/var/sys.config || true && \
	echo "Init Child Chain DB" && \
	_build/${BAREBUILD_ENV}/rel/child_chain/bin/child_chain init_key_value_db && \
	echo "Init Child Chain DB DONE" && \
	_build/${BAREBUILD_ENV}/rel/child_chain/bin/child_chain $(OVERRIDING_START)

start-watcher:
	set -e; . ./bin/variables; \
	echo "Building Watcher" && \
	make build-watcher-${BAREBUILD_ENV} && \
	echo "Potential cleanup" && \
	rm -f ./_build/${BAREBUILD_ENV}/rel/watcher/var/sys.config || true && \
	echo "Init Watcher DBs" && \
	_build/${BAREBUILD_ENV}/rel/watcher/bin/watcher init_key_value_db && \
	echo "Init Watcher DBs DONE" && \
	echo "Run Watcher" && \
	PORT=${WATCHER_PORT} _build/${BAREBUILD_ENV}/rel/watcher/bin/watcher $(OVERRIDING_START)

start-watcher_info:
	set -e; . ./bin/variables; \
	echo "Building Watcher" && \
	make build-watcher_info-${BAREBUILD_ENV} && \
	echo "Potential cleanup" && \
	rm -f ./_build/${BAREBUILD_ENV}/rel/watcher_info/var/sys.config || true && \
	echo "Init Watcher DBs" && \
	_build/${BAREBUILD_ENV}/rel/watcher_info/bin/watcher_info init_key_value_db && \
	_build/${BAREBUILD_ENV}/rel/watcher_info/bin/watcher_info init_postgresql_db && \
	echo "Init Watcher DBs DONE" && \
	echo "Run Watcher" && \
	PORT=${WATCHER_INFO_PORT} _build/${BAREBUILD_ENV}/rel/watcher_info/bin/watcher_info $(OVERRIDING_START)

update-child_chain:
	_build/dev/rel/child_chain/bin/child_chain stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name child_chain --silent && \
	set -e; . ./bin/variables && \
	exec _build/dev/rel/child_chain/bin/child_chain $(OVERRIDING_START) &

update-watcher:
	_build/dev/rel/watcher/bin/watcher stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher --silent && \
	set -e; . ./bin/variables && \
	exec PORT=${WATCHER_PORT} _build/dev/rel/watcher/bin/watcher $(OVERRIDING_START) &

update-watcher_info:
	_build/dev/rel/watcher_info/bin/watcher_info stop ; \
	$(ENV_DEV) mix do compile, distillery.release dev --name watcher_info --silent && \
	set -e; . ./bin/variables && \
	exec PORT=${WATCHER_INFO_PORT} _build/dev/rel/watcher_info/bin/watcher_info $(OVERRIDING_START) &

stop-child_chain:
	_build/dev/rel/child_chain/bin/child_chain stop

stop-watcher:
	_build/dev/rel/watcher/bin/watcher stop

stop-watcher_info:
	_build/dev/rel/watcher/bin/watcher stop

remote-child_chain:
	set -e; . ./bin/variables && \
	_build/dev/rel/child_chain/bin/child_chain remote_console

remote-watcher:
	set -e; . ./bin/variables && \
	_build/dev/rel/watcher/bin/watcher remote_console

remote-watcher_info:
	set -e; . ./bin/variables && \
	_build/dev/rel/watcher_info/bin/watcher_info remote_console

get-alarms:
	echo "Child Chain alarms" ; \
	curl -s -X GET http://localhost:9656/alarm.get ; \
	echo "\nWatcher alarms" ; \
	curl -s -X GET http://localhost:${WATCHER_PORT}/alarm.get ; \
	echo "\nWatcherInfo alarms" ; \
	curl -s -X GET http://localhost:${WATCHER_INFO_PORT}/alarm.get

cluster-stop:
	${MAKE} stop-watcher ; ${MAKE} stop-watcher_info ; ${MAKE} stop-child_chain ; docker-compose down

### git setup
init:
	git config core.hooksPath .githooks

#old git
#init:
#  find .git/hooks -type l -exec rm {} \;
#  find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

###
### SWAGGER openapi
###
security_critical_api_specs:
	swagger-cli bundle -r -t yaml -o apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs.yaml apps/omg_watcher_rpc/priv/swagger/security_critical_api_specs/swagger.yaml

info_api_specs:
	swagger-cli bundle -r -t yaml -o apps/omg_watcher_rpc/priv/swagger/info_api_specs.yaml apps/omg_watcher_rpc/priv/swagger/info_api_specs/swagger.yaml

operator_api_specs:
	swagger-cli bundle -r -t yaml -o apps/omg_child_chain_rpc/priv/swagger/operator_api_specs.yaml apps/omg_child_chain_rpc/priv/swagger/operator_api_specs/swagger.yaml

###
### Diagnostics report
###

diagnostics:
	echo "---------- START OF DIAGNOSTICS REPORT ----------"
	echo "\n---------- CHILDCHAIN LOGS ----------"
	docker-compose logs childchain
	echo "\n---------- WATCHER LOGS ----------"
	docker-compose logs watcher
	echo "\n---------- WATCHER_INFO LOGS ----------"
	docker-compose logs watcher_info
	echo "\n---------- PLASMA CONTRACTS ----------"
	curl -s localhost:8000/contracts | echo "Could not retrieve the deployed plasma contracts."
	echo "\n---------- GIT ----------"
	echo "Git commit: $$(git rev-parse HEAD)"
	git status
	echo "\n---------- DOCKER-COMPOSE CONTAINERS ----------"
	docker-compose ps
	echo "\n---------- DOCKER CONTAINERS ----------"
	docker ps
	echo "\n---------- DOCKER IMAGES ----------"
	docker image ls
	echo "\n ---------- END OF DIAGNOSTICS REPORT ----------"

.PHONY: diagnostics

### UTILS
OSFLAG := ''
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OSFLAG = OSX
endif
