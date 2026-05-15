APP_NAME  = YoutubeAudioExtractor
BUILD_DIR = build
BUNDLE    = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS  = $(BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RES_DIR   = $(CONTENTS)/Resources

SDK    = $(shell xcrun --show-sdk-path)
ARCH   = $(shell uname -m)
TARGET = $(ARCH)-apple-macos13.0

SOURCES = \
	Sources/$(APP_NAME)/App.swift \
	Sources/$(APP_NAME)/ContentView.swift \
	Sources/$(APP_NAME)/AudioExtractor.swift

.PHONY: all deps icon clean open

all: deps icon $(BUNDLE)

Resources/AppIcon.icns: scripts/generate-icon.swift
	@swift scripts/generate-icon.swift
	@iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns
	@rm -rf AppIcon.iconset
	@echo "✓ AppIcon.icns listo"

icon: Resources/AppIcon.icns

$(BUNDLE): $(SOURCES) Resources/Info.plist Resources/AppIcon.icns deps/yt-dlp deps/ffmpeg
	@mkdir -p "$(MACOS_DIR)" "$(RES_DIR)"
	swiftc \
		-sdk "$(SDK)" \
		-target "$(TARGET)" \
		-parse-as-library \
		$(SOURCES) \
		-o "$(MACOS_DIR)/$(APP_NAME)"
	@cp Resources/Info.plist "$(CONTENTS)/"
	@cp Resources/AppIcon.icns "$(RES_DIR)/"
	@cp -R Resources/es.lproj "$(RES_DIR)/"
	@cp deps/yt-dlp "$(RES_DIR)/"
	@cp deps/ffmpeg "$(RES_DIR)/"
	@chmod +x "$(RES_DIR)/yt-dlp" "$(RES_DIR)/ffmpeg"
	@xattr -d com.apple.quarantine "$(RES_DIR)/yt-dlp" "$(RES_DIR)/ffmpeg" 2>/dev/null || true
	@# Ad-hoc sign so macOS allows subprocess execution
	@codesign --force --deep --sign - "$(BUNDLE)" 2>/dev/null || true
	@echo ""
	@echo "✓ Built $(BUNDLE)"
	@echo "  Run: make open"

deps:
	@bash scripts/download-deps.sh

open: all
	@open "$(BUNDLE)"

clean:
	@rm -rf "$(BUILD_DIR)" Resources/AppIcon.icns
	@echo "✓ Cleaned"
