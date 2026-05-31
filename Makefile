.PHONY: build app test clean

build:
	swift build

app:
	./build_app.sh

test: build
	@echo "Build passed"

clean:
	rm -rf .build MoleMac.app
