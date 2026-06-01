.PHONY: build app test parser-test clean

build:
	swift build

app:
	./build_app.sh

test: build
	@echo "Build passed"

# Regression guard for the fragile text parsers (clean/purge/optimize/skip
# markers) against golden fixtures. See Tests/MoguTests.
parser-test:
	swift test

clean:
	rm -rf .build Mogu.app
