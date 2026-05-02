.PHONY: build build-debug build-cli test cli-test ui-test install install-debug install-cli clean generate qa

APP_NAME := RedditReminder
CLI_NAME := redditreminder
PROJ := $(APP_NAME).xcodeproj
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications
BIN_DIR := $(HOME)/bin
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
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

build-cli: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME)CLI \
	  -configuration Debug -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

cli-test: build-cli
	./scripts/cli-smoke.sh "$(BUILD_DIR)/Build/Products/Debug/$(CLI_NAME)"

ui-test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME)UITests \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

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

install-cli: build-cli
	mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR)/Build/Products/Debug/$(CLI_NAME) $(BIN_DIR)/$(CLI_NAME)
	mkdir -p $(BIN_DIR)/RedditReminderResources
	cp Resources/peak-times.json $(BIN_DIR)/RedditReminderResources/peak-times.json

qa: install-debug
	./scripts/qa.sh

clean:
	rm -rf $(PROJ) $(BUILD_DIR)
