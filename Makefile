SERVED_WORK = https://apakabar.fm/api/v1/shadowing/works/shakespeare-sonnets
SERVED_BUILD = parakeet-tdt-0.6b-v3-sherpa-int8
RESOURCES = Tests/ReadAloudKitTests/Resources
FETCH = curl --fail --silent --show-error

.DEFAULT_GOAL := build

.PHONY: build test test-build docs comments lint lint-fix format clean install install-tools served sync-yaml

sync-yaml:
	mkdir -p ../readaloudkit-kotlin/src/test/resources
	cp Tests/ReadAloudKitTests/Resources/*.yaml Tests/ReadAloudKitTests/Resources/*.json ../readaloudkit-kotlin/src/test/resources/
	cp Tests/ReadAloudKitTests/Resources/quirks_tests.yaml Tests/ReadAloudKitTests/Resources/served_hearing.json Tests/ReadAloudKitTests/Resources/spoken_words_tests.yaml Tests/ReadAloudKitTests/Resources/tokenizer_tests.yaml Tests/ReadAloudKitTests/Resources/tracker_tests.yaml ../flowbot/src/flowbot/shadowing/tests/readaloudkit/

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
	commentcensor .

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
	python3 -m pip install --quiet --upgrade git+https://github.com/botforge-pro/commentcensor.git

install:
	$(MAKE) install-tools

served:
	$(FETCH) $(SERVED_WORK)/alignment/shakespeare/18/ -o $(RESOURCES)/served_alignment.json
	$(FETCH) $(SERVED_WORK)/hearing/$(SERVED_BUILD)/ -o $(RESOURCES)/served_hearing.json
