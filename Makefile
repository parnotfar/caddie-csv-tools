MODULE_HOME ?= $(HOME)/.caddie_modules
MODULE_DEST := $(MODULE_HOME)/.caddie_csv
MODULE_VERSION_DEST := $(MODULE_HOME)/.caddie_csv_version
MODULE_SRC_DEST := $(MODULE_HOME)/caddie-csv-src
BIN_DEST := $(MODULE_HOME)/bin/csvql.py
SRC_MODULE := modules/dot_caddie_csv.sh
SRC_MODULE_VERSION := modules/dot_caddie_csv_version
SRC_BIN := bin/csvql.py
SRC_DIR := src

.PHONY: install uninstall lint clean

install:
	@mkdir -p "$(MODULE_HOME)" "$(MODULE_HOME)/bin" "$(MODULE_SRC_DEST)"
	cp "$(SRC_MODULE)" "$(MODULE_DEST)"
	cp "$(SRC_MODULE_VERSION)" "$(MODULE_VERSION_DEST)"
	cp "$(SRC_BIN)" "$(BIN_DEST)"
	cp -r "$(SRC_DIR)"/* "$(MODULE_SRC_DEST)/"
	chmod +x "$(BIN_DEST)"
	@echo "Installed caddie CSV module (modular) to $(MODULE_HOME)"
	@echo "Modules installed to $(MODULE_SRC_DEST)"

uninstall:
	@if [ -f "$(MODULE_DEST)" ]; then rm "$(MODULE_DEST)" && echo "Removed $(MODULE_DEST)"; fi
	@if [ -f "$(MODULE_VERSION_DEST)" ]; then rm "$(MODULE_VERSION_DEST)" && echo "Removed $(MODULE_VERSION_DEST)"; fi
	@if [ -f "$(BIN_DEST)" ]; then rm "$(BIN_DEST)" && echo "Removed $(BIN_DEST)"; fi
	@if [ -d "$(MODULE_SRC_DEST)" ]; then rm -rf "$(MODULE_SRC_DEST)" && echo "Removed $(MODULE_SRC_DEST)"; fi
	@if [ -d "$(MODULE_HOME)/bin" ]; then rmdir "$(MODULE_HOME)/bin" 2>/dev/null || true; fi

clean:
	@echo "Cleaning up temporary files..."
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name "*.swp" -delete 2>/dev/null || true
	@find . -name "*~" -delete 2>/dev/null || true