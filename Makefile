.PHONY: all spec crystal doc clean

-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')
FLAGS := $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )
EXPORTS := $(if $(release),,CRYSTAL_CONFIG_PATH=`pwd`/src)
LLVM_CONFIG := $(shell command -v llvm-config-3.6 llvm-config-3.5 llvm-config | head -n 1)
LLVM_EXT_DIR = src/llvm/ext
LLVM_EXT_OBJ = $(LLVM_EXT_DIR)/llvm_ext.o

all: crystal
spec: all_spec
	$(O)/all_spec
doc:
	$(BUILD_PATH) ./bin/crystal doc docs/main.cr

crystal: $(O)/crystal
all_spec: $(O)/all_spec

$(O)/all_spec: $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) -o $@ spec/all_spec.cr

$(O)/crystal: $(LLVM_EXT_OBJ) $(SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) $(EXPORTS) ./bin/crystal build $(FLAGS) -o $@ src/compiler/crystal.cr

$(LLVM_EXT_OBJ): $(LLVM_EXT_DIR)/llvm_ext.cc
	$(CXX) -c -o $@ $< `$(LLVM_CONFIG) --cxxflags`

clean:
	rm -rf $(O)
	rm -rf ./doc
	rm -rf $(LLVM_EXT_OBJ)
