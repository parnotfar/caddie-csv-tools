CADDIE_HOME ?= $(HOME)/.caddie_modules
MODULE_DEST := $(CADDIE_HOME)/.caddie_csv
BIN_DEST := $(CADDIE_HOME)/bin/csvql.py
SRC_MODULE := modules/dot_caddie_csv.sh
SRC_BIN := bin/csvql.py

.PHONY: install uninstall lint

install:
	@mkdir -p "$(CADDIE_HOME)" "$(CADDIE_HOME)/bin"
	cp "$(SRC_MODULE)" "$(MODULE_DEST)"
	chmod +x "$(MODULE_DEST)"
	cp "$(SRC_BIN)" "$(BIN_DEST)"
	chmod +x "$(BIN_DEST)"
	@echo "Installed caddie CSV module to $(CADDIE_HOME)"

uninstall:
	@if [ -f "$(MODULE_DEST)" ]; then rm "$(MODULE_DEST)" && echo "Removed $(MODULE_DEST)"; fi
	@if [ -f "$(BIN_DEST)" ]; then rm "$(BIN_DEST)" && echo "Removed $(BIN_DEST)"; fi