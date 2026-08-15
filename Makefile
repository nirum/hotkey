APP_NAME = Hotkey
BUILD_DIR = .build/release
BUNDLE = $(APP_NAME).app
INSTALL_DIR = ~/Applications

ICON      = design/icon.svg
ICON_SM   = design/icon-small.svg
MENUBAR   = design/menubar.svg
RSVG      = rsvg-convert

.PHONY: build app install uninstall clean icon check-tools

build:
	swift build -c release

check-tools:
	@command -v $(RSVG) >/dev/null 2>&1 || \
		{ echo "rsvg-convert not found — brew install librsvg"; exit 1; }

# Every slice is rendered from vector at its target size. The 16pt slices
# (16px and 32px) run the simplified mark, which drops the H so the ⌘ has room
# to keep its counters open — see design/icon-small.svg.
icon: check-tools
	rm -rf AppIcon.iconset
	mkdir -p AppIcon.iconset
	$(RSVG) -w 16   -h 16   $(ICON_SM) -o AppIcon.iconset/icon_16x16.png
	$(RSVG) -w 32   -h 32   $(ICON_SM) -o AppIcon.iconset/icon_16x16@2x.png
	$(RSVG) -w 32   -h 32   $(ICON_SM) -o AppIcon.iconset/icon_32x32.png
	$(RSVG) -w 64   -h 64   $(ICON)    -o AppIcon.iconset/icon_32x32@2x.png
	$(RSVG) -w 128  -h 128  $(ICON)    -o AppIcon.iconset/icon_128x128.png
	$(RSVG) -w 256  -h 256  $(ICON)    -o AppIcon.iconset/icon_128x128@2x.png
	$(RSVG) -w 256  -h 256  $(ICON)    -o AppIcon.iconset/icon_256x256.png
	$(RSVG) -w 512  -h 512  $(ICON)    -o AppIcon.iconset/icon_256x256@2x.png
	$(RSVG) -w 512  -h 512  $(ICON)    -o AppIcon.iconset/icon_512x512.png
	$(RSVG) -w 1024 -h 1024 $(ICON)    -o AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns AppIcon.iconset -o AppIcon.icns
	rm -rf AppIcon.iconset
	$(RSVG) -w 1024 -h 1024 $(ICON) -o logo.png

app: build icon
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp AppIcon.icns $(BUNDLE)/Contents/Resources/
	$(RSVG) -w 28 -h 22 $(MENUBAR) -o $(BUNDLE)/Contents/Resources/menubar-icon.png
	$(RSVG) -w 56 -h 44 $(MENUBAR) -o $(BUNDLE)/Contents/Resources/menubar-icon@2x.png
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
