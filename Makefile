COMMENTCENSOR_VERSION ?= v0.3.2
COMMENTCENSOR_ENV = .build/commentcensor
COMMENTCENSOR = $(COMMENTCENSOR_ENV)/bin/commentcensor

.DEFAULT_GOAL := build

.PHONY: build test test-build docs comments lint lint-fix format clean install install-tools

build: lint test-build test docs
	swift build

test:
	swift test

test-build:
	swift build --build-tests

docs:
	swift package --allow-writing-to-directory .build/docc generate-documentation \
		--target ReadAloudKit --output-path .build/docc \
		--warnings-as-errors \
		--transform-for-static-hosting \
		--hosting-base-path readaloudkit-swift

comments:
	$(COMMENTCENSOR) .

lint: comments
	swiftlint --strict
	swift-format lint --strict --recursive Sources Tests Package.swift

lint-fix:
	$(MAKE) format

format:
	swift-format format --in-place --recursive Sources Tests Package.swift

clean:
	swift package clean
	rm -rf .build

install-tools:
	brew install swiftlint swift-format
	python3 -m venv $(COMMENTCENSOR_ENV)
	$(COMMENTCENSOR_ENV)/bin/pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git@$(COMMENTCENSOR_VERSION)

install:
	$(MAKE) install-tools
