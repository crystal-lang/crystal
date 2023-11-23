
## Run all data generators
##   $ make -B -f scripts/generate_data.mk
## Run specific data generator
##   $ make -B -f scripts/generate_data.mk spec/std/string/graphemes_break_spec.cr

all: ## Run all generators
.PHONY: all

all: spec/std/string/graphemes_break_spec.cr
spec/std/string/graphemes_break_spec.cr: scripts/generate_grapheme_break_specs.cr
	bin/crystal run $<

all: src/string/grapheme/properties.cr
src/string/grapheme/properties.cr: scripts/generate_grapheme_properties.cr
	bin/crystal run $<

all: src/openssl/ssl/defaults.cr
src/openssl/ssl/defaults.cr: scripts/generate_ssl_server_defaults.cr
	bin/crystal run $<

all: src/unicode/data.cr
src/unicode/data.cr: scripts/generate_unicode_data.cr
	bin/crystal run $<

all: src/crystal/system/win32/zone_names.cr
src/crystal/system/win32/zone_names.cr: scripts/generate_windows_zone_names.cr
	bin/crystal run $<

all: src/html/entities.cr
src/html/entities.cr: scripts/generate_html_entities.cr scripts/html_entities.ecr
	bin/crystal run $<

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
