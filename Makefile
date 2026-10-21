.PHONY: build test run demo app

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

run: app
	open dist/Brainstorm.app

demo: app
	open -n dist/Brainstorm.app --args --demo
