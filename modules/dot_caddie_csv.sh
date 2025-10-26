#!/usr/bin/env bash

# Caddie CSV Tools - Main Entry Point
# Modular CSV/TSV analytics helpers for caddie.sh

# Define module paths
CADDIE_CSV_MODULE_HOME="${HOME}/.caddie_modules"
CADDIE_CSV_MODULE_SRC="${CADDIE_CSV_MODULE_HOME}/caddie-csv-src"

# Source caddie CLI utilities
source "${CADDIE_CSV_MODULE_HOME}/.caddie_cli"
source "${CADDIE_CSV_MODULE_HOME}/.caddie_csv_version"

# Source all modules in dependency order
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_core.sh"
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_session.sh"
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_settings.sh"
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_sql.sh"
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_query.sh"
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_prompt.sh"
source "${CADDIE_CSV_MODULE_SRC}/caddie_csv_main.sh"