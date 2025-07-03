CRYSTAL := ../bin/crystal## Crystal compiler to use
O := .build## Output directory

BUILDABLE_SOURCES := $(wildcard *.cr llvm/*.cr compiler/*.cr)
NONLINK_SOURCES := $(wildcard sdl/*.cr)

BUILDABLE_BINARIES := $(patsubst %.cr,$(O)/%,$(BUILDABLE_SOURCES))
NONLINK_BINARIES := $(patsubst %.cr,$(O)/%.o,$(NONLINK_SOURCES))

.PHONY: all
all: build

.PHONY: build
build: $(BUILDABLE_BINARIES) $(NONLINK_BINARIES) ## Build sample binaries

$(O)/%: %.cr
	mkdir -p $(shell dirname $@)
	$(CRYSTAL) build $< -o $@

$(O)/%.o: %.cr
	mkdir -p $(shell dirname $@)
	$(CRYSTAL) build --cross-compile $< -o $(patsubst %.o,%,$@)

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(O)

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
