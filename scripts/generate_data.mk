
## Run all data generators
##   $ make -f scripts/generate_data.mk
## Generate time zone database for stdlib specs
##   $ make zoneinfo -f scripts/generate_data.mk

TZDB_VERSION := 2025b

ifeq ($(OS),Windows_NT)
  BIN_CRYSTAL=bin\crystal
else
  BIN_CRYSTAL=bin/crystal
endif

.PHONY: all
all: zoneinfo ## Run all generators
	$(BIN_CRYSTAL) run scripts/generate_grapheme_break_specs.cr
	$(BIN_CRYSTAL) run scripts/generate_grapheme_properties.cr
	$(BIN_CRYSTAL) run scripts/generate_ssl_server_defaults.cr
	$(BIN_CRYSTAL) run scripts/generate_unicode_data.cr
	$(BIN_CRYSTAL) run scripts/generate_windows_zone_names.cr
	$(BIN_CRYSTAL) run scripts/generate_html_entities.cr

.PHONY: zoneinfo
zoneinfo: spec/std/data/zoneinfo.zip ## Generate time zone database for stdlib specs

spec/std/data/zoneinfo.zip:
	wget -O- https://data.iana.org/time-zones/tzdb-latest.tar.lz | tar -x --lzip
	$(MAKE) -C 'tzdb-$(TZDB_VERSION)' zones REDO=posix_only DESTDIR=stage TZDIR=/ ZFLAGS='-b fat'
	rm -f spec/std/data/zoneinfo.zip
	cd 'tzdb-$(TZDB_VERSION)/stage' && zip -0 -r ../../spec/std/data/zoneinfo.zip .

.PHONY: help
help: ## Show this help
	@echo
	@printf '\033[34mtargets:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34moptional variables:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+ \?=.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = " \\?=.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mrecipes:\033[0m\n'
	@grep -hE '^##.*$$' $(MAKEFILE_LIST) |\
		awk 'BEGIN {FS = "## "}; /^## [a-zA-Z_-]/ {printf "  \033[36m%s\033[0m\n", $$2}; /^##  / {printf "  %s\n", $$2}'
