-include Makefile.local # for optional local options e.g. threads

# Recipes for this Makefile

## Build the compiler
##   $ make
## Build the compiler with progress output
##   $ make progress=true
## Clean up built files then build the compiler
##   $ make clean crystal
## Build the compiler in release mode
##   $ make crystal release=1
## Run all specs in verbose mode
##   $ make spec verbose=1

LLVM_CONFIG ?= ## llvm-config command path to use

release ?=      ## Compile in release mode
stats ?=        ## Enable statistics output
progress ?=     ## Enable progress output
threads ?=      ## Maximum number of threads to use
debug ?=        ## Add symbolic debug info
verbose ?=      ## Run specs in verbose mode
junit_output ?= ## Directory to output junit results
static ?=       ## Enable static linking

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')
override FLAGS += $(if $(release),--release )$(if $(stats),--stats )$(if $(progress),--progress )$(if $(threads),--threads $(threads) )$(if $(debug),-d )$(if $(static),--static )$(if $(LDFLAGS),--link-flags="$(LDFLAGS)" )
SPEC_WARNINGS_OFF := --exclude-warnings spec/std --exclude-warnings spec/compiler
SPEC_FLAGS := $(if $(verbose),-v )$(if $(junit_output),--junit_output $(junit_output) )
CRYSTAL_CONFIG_BUILD_COMMIT := $(shell git rev-parse --short HEAD 2> /dev/null)
EXPORTS := \
  $(if $(release),,CRYSTAL_CONFIG_PATH="$(PWD)/src") \
  CRYSTAL_CONFIG_LIBRARY_PATH="$(shell crystal env CRYSTAL_LIBRARY_PATH)" \
  CRYSTAL_CONFIG_BUILD_COMMIT="$(CRYSTAL_CONFIG_BUILD_COMMIT)"
SHELL = sh
LLVM_CONFIG_FINDER := \
  [ -n "$(LLVM_CONFIG)" ] && command -v "$(LLVM_CONFIG)" || \
  command -v llvm-config-8 || command -v llvm-config-8.0 || command -v llvm-config80 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 8.0*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-7 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 7.1*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-7.0 || command -v llvm-config70 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 7.0*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-6.0 || command -v llvm-config60 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 6.0*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-5.0 || command -v llvm-config50 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 5.0*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-4.0 || command -v llvm-config40 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 4.0*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-3.9 || command -v llvm-config39 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 3.9*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config-3.8 || command -v llvm-config38 || \
    (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 3.8*) command -v llvm-config;; *) false;; esac)) || \
  command -v llvm-config
LLVM_CONFIG := $(shell $(LLVM_CONFIG_FINDER))
LLVM_EXT_DIR = src/llvm/ext
LLVM_EXT_OBJ = $(LLVM_EXT_DIR)/llvm_ext.o
LIB_CRYSTAL_SOURCES = $(shell find src/ext -name '*.c')
LIB_CRYSTAL_OBJS = $(subst .c,.o,$(LIB_CRYSTAL_SOURCES))
LIB_CRYSTAL_TARGET = src/ext/libcrystal.a
DEPS = $(LLVM_EXT_OBJ) $(LIB_CRYSTAL_TARGET)
CFLAGS += -fPIC $(if $(debug),-g -O0)
CXXFLAGS += $(if $(debug),-g -O0)

ifeq (${LLVM_CONFIG},)
  $(error Could not locate llvm-config, make sure it is installed and in your PATH, or set LLVM_CONFIG)
else
  $(shell echo $(shell printf '\033[33m')Using $(LLVM_CONFIG) [version=$(shell $(LLVM_CONFIG) --version)]$(shell printf '\033[0m') >&2)
endif

.PHONY: all
all: crystal ## Build all files (currently crystal only) [default]

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

.PHONY: spec
spec: $(O)/all_spec ## Run all specs
	$(O)/all_spec $(SPEC_FLAGS)

.PHONY: std_spec
std_spec: $(O)/std_spec ## Run standard library specs
	$(O)/std_spec $(SPEC_FLAGS)

.PHONY: compiler_spec
compiler_spec: $(O)/compiler_spec ## Run compiler specs
	$(O)/compiler_spec $(SPEC_FLAGS)

.PHONY: docs
docs: ## Generate standard library documentation
	$(BUILD_PATH) ./bin/crystal docs src/docs_main.cr $(DOCS_OPTIONS)

.PHONY: crystal
crystal: $(O)/crystal ## Build the compiler

.PHONY: deps llvm_ext libcrystal
deps: $(DEPS) ## Build dependencies

llvm_ext: $(LLVM_EXT_OBJ)
libcrystal: $(LIB_CRYSTAL_TARGET)

$(O)/all_spec: $(DEPS) $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) $(SPEC_WARNINGS_OFF) -o $@ spec/all_spec.cr

$(O)/std_spec: $(DEPS) $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) $(SPEC_WARNINGS_OFF) -o $@ spec/std_spec.cr

$(O)/compiler_spec: $(DEPS) $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) $(SPEC_WARNINGS_OFF) -o $@ spec/compiler_spec.cr

$(O)/crystal: $(DEPS) $(SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) $(EXPORTS) ./bin/crystal build $(FLAGS) -o $@ src/compiler/crystal.cr -D without_openssl -D without_zlib

$(LLVM_EXT_OBJ): $(LLVM_EXT_DIR)/llvm_ext.cc
	$(CXX) -c $(CXXFLAGS) -o $@ $< $(shell $(LLVM_CONFIG) --cxxflags)

$(LIB_CRYSTAL_TARGET): $(LIB_CRYSTAL_OBJS)
	$(AR) -rcs $@ $^

.PHONY: clean
clean: clean_crystal ## Clean up built directories and files
	rm -rf $(LLVM_EXT_OBJ)
	rm -rf $(LIB_CRYSTAL_OBJS) $(LIB_CRYSTAL_TARGET)

.PHONY: clean_crystal
clean_crystal: ## Clean up crystal built files
	rm -rf $(O)
	rm -rf ./docs

.PHONY: clean_cache
clean_cache: ## Clean up CRYSTAL_CACHE_DIR files
	rm -rf $(shell ./bin/crystal env CRYSTAL_CACHE_DIR)
