COMMENTCENSOR_VERSION ?= v0.3.1
COMMENTCENSOR_ENV = .build/commentcensor
COMMENTCENSOR = $(COMMENTCENSOR_ENV)/bin/commentcensor

.DEFAULT_GOAL := build

.PHONY: install-tools format comments lint test-build test docs build install

install-tools:
	brew install swiftlint
	python3 -m venv $(COMMENTCENSOR_ENV)
	$(COMMENTCENSOR_ENV)/bin/pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git@$(COMMENTCENSOR_VERSION)

format:
	swiftlint --fix

comments:
	$(COMMENTCENSOR) .

lint: comments
	swiftlint --strict

test-build:
	swift build --build-tests

test:
	swift test

docs:
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target WikilayerClient --output-path .build/docc \
		--warnings-as-errors \
		--transform-for-static-hosting \
		--hosting-base-path wikilayer-client-swift

build: lint test-build test docs
	swift build

install:
	$(MAKE) install-tools
