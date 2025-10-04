MODULE_HOME ?= $(HOME)/.caddie_modules
MODULE_DEST := $(MODULE_HOME)/.caddie_csv
MODULE_VERSION_DEST := $(MODULE_HOME)/.caddie_csv_version
BIN_DEST := $(MODULE_HOME)/bin/csvql.py
SRC_MODULE := modules/dot_caddie_csv.sh
SRC_MODULE_VERSION := modules/dot_caddie_csv_version
SRC_BIN := bin/csvql.py

.PHONY: install uninstall lint

install:
	@mkdir -p "$(MODULE_HOME)" "$(MODULE_HOME)/bin"
	cp "$(SRC_MODULE)" "$(MODULE_DEST)"
	cp "$(SRC_MODULE_VERSION)" "$(MODULE_VERSION_DEST)"
	cp "$(SRC_BIN)" "$(BIN_DEST)"
	chmod +x "$(BIN_DEST)"
	@echo "Installed caddie CSV module to $(MODULE_HOME)"

uninstall:
	@if [ -f "$(MODULE_DEST)" ]; then rm "$(MODULE_DEST)" && echo "Removed $(MODULE_DEST)"; fi
	@if [ -f "$(MODULE_VERSION_DEST)" ]; then rm "$(MODULE_VERSION_DEST)" && echo "Removed $(MODULE_VERSION_DEST)"; fi
	@if [ -f "$(BIN_DEST)" ]; then rm "$(BIN_DEST)" && echo "Removed $(BIN_DEST)"; fi
	@if [ -d "$(MODULE_HOME)/bin" ]; then rmdir "$(MODULE_HOME)/bin" 2>/dev/null || true; fi