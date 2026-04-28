.PHONY: build build-debug test install install-debug clean generate qa

APP_NAME := RedditReminder
PROJ := $(APP_NAME).xcodeproj
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications
LABEL := com.neonwatty.$(APP_NAME)

# Copy the built .app into INSTALL_DIR.  $(1) = configuration name (Release | Debug)
define copy_app
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(BUILD_DIR)/Build/Products/$(1)/$(APP_NAME).app $(INSTALL_DIR)/
endef

generate:
	xcodegen generate

build: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

build-debug: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -configuration Debug -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

install: build
	$(call copy_app,Release)
	@if [ -f "$(HOME)/Library/LaunchAgents/$(LABEL).plist" ]; then \
	  echo "LaunchAgent detected -- restarting managed instance"; \
	  launchctl kickstart -k "gui/$$(id -u)/$(LABEL)"; \
	else \
	  open $(INSTALL_DIR)/$(APP_NAME).app; \
	fi

install-debug: build-debug
	$(call copy_app,Debug)

qa: install-debug
	./scripts/qa.sh

clean:
	rm -rf $(PROJ) $(BUILD_DIR)
