.DEFAULT_GOAL := build

.PHONY: format lint test-build test docs build install

format:
	swiftlint --fix

lint:
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

build: lint test

install:
	brew install swiftlint
