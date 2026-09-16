.DEFAULT_GOAL := build

.PHONY: format lint test-build test build install

format:
	swiftlint --fix

lint:
	swiftlint --strict

test-build:
	swift build --build-tests

test:
	swift test

build: format lint test

install:
	brew install swiftlint
