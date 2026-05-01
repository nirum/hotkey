APP_NAME = Hotkey
BUILD_DIR = .build/release
BUNDLE = $(APP_NAME).app
INSTALL_DIR = ~/Applications

.PHONY: build app install uninstall clean

build:
	swift build -c release

icon:
	rm -rf AppIcon.iconset
	mkdir -p AppIcon.iconset
	sips -z 16 16     logo.png --out AppIcon.iconset/icon_16x16.png
	sips -z 32 32     logo.png --out AppIcon.iconset/icon_16x16@2x.png
	sips -z 32 32     logo.png --out AppIcon.iconset/icon_32x32.png
	sips -z 64 64     logo.png --out AppIcon.iconset/icon_32x32@2x.png
	sips -z 128 128   logo.png --out AppIcon.iconset/icon_128x128.png
	sips -z 256 256   logo.png --out AppIcon.iconset/icon_128x128@2x.png
	sips -z 256 256   logo.png --out AppIcon.iconset/icon_256x256.png
	sips -z 512 512   logo.png --out AppIcon.iconset/icon_256x256@2x.png
	sips -z 512 512   logo.png --out AppIcon.iconset/icon_512x512.png
	sips -z 1024 1024 logo.png --out AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns AppIcon.iconset -o AppIcon.icns
	rm -rf AppIcon.iconset

app: build icon
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp AppIcon.icns $(BUNDLE)/Contents/Resources/
	sips -z 44 44 logo.png --out $(BUNDLE)/Contents/Resources/menubar-icon@2x.png
	sips -z 22 22 logo.png --out $(BUNDLE)/Contents/Resources/menubar-icon.png
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
		-c "Add :CFBundleIconFile string AppIcon" \
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
