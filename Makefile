
# Makefile for TNotch

APP_NAME = LiquidNotch
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
EXECUTABLE = $(APP_NAME)
PLIST = Info.plist
ICON = Resources/AppIcon.icns

all: build package

build:
	swift build -c release

package:
	@echo "Packaging $(APP_BUNDLE)..."
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(EXECUTABLE) $(APP_BUNDLE)/Contents/MacOS/
	cp $(PLIST) $(APP_BUNDLE)/Contents/
	@if [ -f $(ICON) ]; then cp $(ICON) $(APP_BUNDLE)/Contents/Resources/; fi
	chmod +x $(APP_BUNDLE)/Contents/MacOS/$(EXECUTABLE)
	xattr -cr $(APP_BUNDLE)
	codesign --force --deep --sign - --entitlements LiquidNotch.entitlements $(APP_BUNDLE)
	@echo "Done! App bundle created at $(APP_BUNDLE)"

clean:
	rm -rf .build $(APP_BUNDLE)
