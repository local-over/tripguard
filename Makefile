.PHONY: all build bundle run clean zip screenshots

all: bundle

build:
	swift build -c release

bundle:
	./bundle.sh

run: bundle
	open TripGuard.app

zip: bundle
	zip -r -y TripGuard-macos.zip TripGuard.app
	@echo "Created TripGuard-macos.zip"

screenshots:
	swift generate_perfect_screenshots.swift

clean:
	rm -rf .build TripGuard.app TripGuard.dmg TripGuard-macos.zip
