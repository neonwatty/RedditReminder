.PHONY: agent-bootstrap build build-debug build-dev build-cli test cli-test ui-test release-dry-run release-dmg install install-debug install-dev install-cli start start-dev stop stop-dev clean generate qa qa-seed qa-clear

APP_NAME := RedditReminder
DEV_APP_NAME := RedditReminder Dev
CLI_NAME := redditreminder
PROJ := $(APP_NAME).xcodeproj
APP_SCHEME := $(APP_NAME)
DEV_SCHEME := RedditReminderDev
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications
BIN_DIR := $(HOME)/bin
LABEL := com.neonwatty.$(APP_NAME)
DEV_LABEL := com.neonwatty.$(APP_NAME).Dev

# Copy a built .app into INSTALL_DIR.  $(1) = configuration name, $(2) = app name
define copy_app
	mkdir -p $(INSTALL_DIR)
	rm -rf "$(INSTALL_DIR)/$(2).app"
	cp -R "$(BUILD_DIR)/Build/Products/$(1)/$(2).app" "$(INSTALL_DIR)/"
endef

generate:
	xcodegen generate

build: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_SCHEME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

build-debug: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_SCHEME) \
	  -configuration Debug -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

build-dev: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(DEV_SCHEME) \
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
	  -project $(PROJ) -scheme $(APP_SCHEME)CLI \
	  -configuration Debug -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

release-dry-run: generate
	scripts/build-release-dmg.sh --dry-run

release-dmg: generate
	@if [ -z "$(VERSION)" ] || [ -z "$(BUILD)" ]; then \
	  echo "Usage: make release-dmg VERSION=0.1.0 BUILD=1" >&2; \
	  exit 2; \
	fi
	VERSION="$(VERSION)" BUILD_NUMBER="$(BUILD)" scripts/build-release-dmg.sh

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_SCHEME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

cli-test: build-cli
	@./scripts/agent-bootstrap.sh >/dev/null
	./scripts/cli-smoke.sh "$(BUILD_DIR)/Build/Products/Debug/$(CLI_NAME)"
	./scripts/cli-agent-smoke.sh "$(BUILD_DIR)/Build/Products/Debug/$(CLI_NAME)"
	./scripts/cli-catalog-check.py "$(BUILD_DIR)/Build/Products/Debug/$(CLI_NAME)"

agent-bootstrap:
	@./scripts/agent-bootstrap.sh

ui-test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_SCHEME)UITests \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  CODE_SIGN_IDENTITY=- \
	  CODE_SIGN_STYLE=Manual \
	  DEVELOPMENT_TEAM= \
	  ENABLE_DEBUG_DYLIB=NO \
	  ENABLE_HARDENED_RUNTIME=NO \
	  OTHER_CODE_SIGN_FLAGS=

install: build
	$(call copy_app,Release,$(APP_NAME))
	@if [ -f "$(HOME)/Library/LaunchAgents/$(LABEL).plist" ]; then \
	  echo "LaunchAgent detected -- restarting managed instance"; \
	  launchctl kickstart -k "gui/$$(id -u)/$(LABEL)"; \
	else \
	  open "$(INSTALL_DIR)/$(APP_NAME).app"; \
	fi

install-debug: build-debug
	$(call copy_app,Debug,$(APP_NAME))

install-dev: build-dev
	$(call copy_app,Debug,$(DEV_APP_NAME))

start:
	open "$(INSTALL_DIR)/$(APP_NAME).app"

start-dev:
	open "$(INSTALL_DIR)/$(DEV_APP_NAME).app"

stop:
	-pkill -x "$(APP_NAME)" 2>/dev/null || true

stop-dev:
	-pkill -x "$(DEV_APP_NAME)" 2>/dev/null || true

install-cli: build-cli
	mkdir -p $(BIN_DIR)
	cp $(BUILD_DIR)/Build/Products/Debug/$(CLI_NAME) $(BIN_DIR)/$(CLI_NAME)
	mkdir -p $(BIN_DIR)/RedditReminderResources
	cp Resources/peak-times.json $(BIN_DIR)/RedditReminderResources/peak-times.json

qa: install-debug
	./scripts/qa.sh

qa-seed: install-debug
	-pkill -x $(APP_NAME) 2>/dev/null || true
	open "$(INSTALL_DIR)/$(APP_NAME).app" --args --seed-qa

qa-clear: install-debug
	-pkill -x $(APP_NAME) 2>/dev/null || true
	open "$(INSTALL_DIR)/$(APP_NAME).app" --args --clear-qa

clean:
	rm -rf $(PROJ) $(BUILD_DIR)
