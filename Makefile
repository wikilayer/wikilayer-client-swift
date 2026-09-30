.DEFAULT_GOAL := build

.PHONY: install-tools format comments lint test-build test docs build install sync-yaml

sync-yaml:
	mkdir -p ../wikilayer-client-kotlin/src/test/resources
	cp Tests/WikilayerClientTests/Resources/*.yaml ../wikilayer-client-kotlin/src/test/resources/

install-tools:
	brew install swiftlint swift-format
	python3 -m pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git

format:
	swift-format format --in-place --recursive Sources Tests Package.swift

comments:
	commentcensor .

lint: comments
	swiftlint --strict
	swift-format lint --strict --recursive Sources Tests Package.swift

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
