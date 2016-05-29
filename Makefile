.PHONY: all spec std_spec compiler_spec doc crystal \
	all_spec all_compiler_spec all_std_spec \
	llvm_ext libcrystal deps clean

-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')
FLAGS := $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )$(if $(debug),-d )
EXPORTS := $(if $(release),,CRYSTAL_CONFIG_PATH=`pwd`/src)
SHELL = bash
LLVM_CONFIG := $(shell command -v llvm-config-3.6 llvm-config36 llvm-config-3.5 llvm-config35 llvm-config | head -n 1)
LLVM_EXT_DIR = src/llvm/ext
LLVM_EXT_OBJ = $(LLVM_EXT_DIR)/llvm_ext.o
LIB_CRYSTAL_SOURCES = $(shell find src/ext -name '*.c')
LIB_CRYSTAL_OBJS = $(subst .c,.o,$(LIB_CRYSTAL_SOURCES))
LIB_CRYSTAL_TARGET = src/ext/libcrystal.a
CFLAGS += -fPIC

ifeq (${LLVM_CONFIG},)
$(error Could not locate llvm-config, make sure it is installed and in your PATH)
endif

all: crystal

help: ## Show this help
	@printf '\033[34mtargets:\033[0m\n'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

spec: all_spec ## Run all specs
	$(O)/all_spec

std_spec: all_std_spec ## Run standard library specs
	$(O)/std_spec

compiler_spec: all_compiler_spec ## Run compiler specs
	$(O)/compiler_spec

doc: ## Generate standard library documentation
	$(BUILD_PATH) ./bin/crystal doc src/docs_main.cr

crystal: $(O)/crystal ## Build the compiler

all_spec: $(O)/all_spec
all_std_spec: $(O)/std_spec
all_compiler_spec: $(O)/compiler_spec

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
	$(CXX) -c -o $@ $< `$(LLVM_CONFIG) --cxxflags`

$(LIB_CRYSTAL_TARGET): $(LIB_CRYSTAL_OBJS)
	ar -rcs $@ $^

clean: ## Clean up built directories and files
	rm -rf $(O)
	rm -rf ./doc
	rm -rf $(LLVM_EXT_OBJ)
	rm -rf $(LIB_CRYSTAL_OBJS) $(LIB_CRYSTAL_TARGET)
