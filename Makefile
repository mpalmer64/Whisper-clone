.PHONY: app install run clean

app:
	./scripts/build-app.sh

install: app
	rm -rf /Applications/WhisperKey.app
	cp -R build/WhisperKey.app /Applications/
	@echo "✓ Installed. Launch with: open /Applications/WhisperKey.app"

run: app
	open build/WhisperKey.app

clean:
	rm -rf .build build
