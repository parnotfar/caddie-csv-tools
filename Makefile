INSTALL_CADDIE_HOME ?= $(HOME)
MODULE_HOME ?= $(INSTALL_CADDIE_HOME)/.caddie_modules
MODULE_DEST := $(MODULE_HOME)/.caddie_csv
BIN_DEST := $(INSTALL_CADDIE_HOME)/.caddie_bin/csvql.py
SRC_MODULE := modules/dot_caddie_csv.sh
SRC_BIN := bin/csvql.py

.PHONY: install uninstall lint

install:
	@mkdir -p "$(MODULE_HOME)" "$(INSTALL_CADDIE_HOME)/.caddie_bin"
	cp "$(SRC_MODULE)" "$(MODULE_DEST)"
	cp "$(SRC_BIN)" "$(BIN_DEST)"
	chmod +x "$(BIN_DEST)"
	@echo "Installed caddie CSV module to $(MODULE_HOME)"

uninstall:
	@if [ -f "$(MODULE_DEST)" ]; then rm "$(MODULE_DEST)" && echo "Removed $(MODULE_DEST)"; fi
	@if [ -f "$(BIN_DEST)" ]; then rm "$(BIN_DEST)" && echo "Removed $(BIN_DEST)"; fi