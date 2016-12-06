-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')
FLAGS := $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )$(if $(debug),-d )
VERBOSE := $(if $(verbose),-v )
EXPORTS := $(if $(release),,CRYSTAL_CONFIG_PATH=`pwd`/src)
SHELL = bash
LLVM_CONFIG_FINDER := \
	[ -n "$(LLVM_CONFIG)" ] && command -v "$(LLVM_CONFIG)" || \
	command -v llvm-config-3.9 || command -v llvm-config39 || (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 3.9*) command -v llvm-config;; *) false;; esac)) || \
	command -v llvm-config-3.8 || command -v llvm-config38 || (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 3.8*) command -v llvm-config;; *) false;; esac)) || \
	command -v llvm-config-3.6 || command -v llvm-config36 || \
	command -v llvm-config-3.5 || command -v llvm-config35 || \
	command -v llvm-config
LLVM_CONFIG := $(shell $(LLVM_CONFIG_FINDER))
LLVM_EXT_DIR = src/llvm/ext
LLVM_EXT_OBJ = $(LLVM_EXT_DIR)/llvm_ext.o
LIB_CRYSTAL_SOURCES = $(shell find src/ext -name '*.c')
LIB_CRYSTAL_OBJS = $(subst .c,.o,$(LIB_CRYSTAL_SOURCES))
LIB_CRYSTAL_TARGET = src/ext/libcrystal.a
CFLAGS += -fPIC $(if $(debug),-g -O0)
CXXFLAGS += $(if $(debug),-g -O0)

ifeq (${LLVM_CONFIG},)
  $(error Could not locate llvm-config, make sure it is installed and in your PATH, or set LLVM_CONFIG)
else
  $(info Using $(LLVM_CONFIG) [version=$(shell $(LLVM_CONFIG) --version)])
endif

.PHONY: all
all: crystal

.PHONY: help
help: ## Show this help
	@printf '\033[34mtargets:\033[0m\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

.PHONY: spec
spec: all_spec ## Run all specs
	$(O)/all_spec $(VERBOSE)

.PHONY: std_spec
std_spec: all_std_spec ## Run standard library specs
	$(O)/std_spec $(VERBOSE)

.PHONY: compiler_spec
compiler_spec: all_compiler_spec ## Run compiler specs
	$(O)/compiler_spec $(VERBOSE)

.PHONY: doc
doc: ## Generate standard library documentation
	$(BUILD_PATH) ./bin/crystal doc src/docs_main.cr

.PHONY: crystal
crystal: $(O)/crystal ## Build the compiler

.PHONY: all_spec all_std_spec all_compiler_spec
all_spec: $(O)/all_spec
all_std_spec: $(O)/std_spec
all_compiler_spec: $(O)/compiler_spec

.PHONY: llvm_ext libcrystal deps
llvm_ext: $(LLVM_EXT_OBJ)
libcrystal: $(LIB_CRYSTAL_TARGET)
deps: llvm_ext libcrystal

$(O)/all_spec: deps $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) -o $@ spec/all_spec.cr

$(O)/std_spec: deps $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) -o $@ spec/std_spec.cr

$(O)/compiler_spec: deps $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) -o $@ spec/compiler_spec.cr

$(O)/crystal: deps $(SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) $(EXPORTS) ./bin/crystal build $(FLAGS) -o $@ src/compiler/crystal.cr -D without_openssl -D without_zlib

$(LLVM_EXT_OBJ): $(LLVM_EXT_DIR)/llvm_ext.cc
	$(CXX) -c $(CXXFLAGS) -o $@ $< `$(LLVM_CONFIG) --cxxflags`

$(LIB_CRYSTAL_TARGET): $(LIB_CRYSTAL_OBJS)
	ar -rcs $@ $^

.PHONY: clean
clean: ## Clean up built directories and files
	rm -rf $(O)
	rm -rf ./doc
	rm -rf $(LLVM_EXT_OBJ)
	rm -rf $(LIB_CRYSTAL_OBJS) $(LIB_CRYSTAL_TARGET)
