APP_NAME = Hotkey
BUILD_DIR = .build/release
BUNDLE = $(APP_NAME).app
INSTALL_DIR = ~/Applications

.PHONY: build app install uninstall clean

build:
	swift build -c release

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	@/usr/libexec/PlistBuddy -c "Clear dict" $(BUNDLE)/Contents/Info.plist 2>/dev/null; \
	/usr/libexec/PlistBuddy \
		-c "Add :CFBundleIdentifier string com.hotkey.app" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundleExecutable string $(APP_NAME)" \
		-c "Add :CFBundleVersion string 1.0" \
		-c "Add :CFBundleShortVersionString string 1.0" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :LSMinimumSystemVersion string 13.0" \
		-c "Add :LSUIElement bool true" \
		$(BUNDLE)/Contents/Info.plist

install: app
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(BUNDLE)
	cp -r $(BUNDLE) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(BUNDLE)"

uninstall:
	rm -rf $(INSTALL_DIR)/$(BUNDLE)
	rm -f ~/Library/LaunchAgents/com.hotkey.app.plist
	@echo "Uninstalled"

clean:
	swift package clean
	rm -rf $(BUNDLE)
