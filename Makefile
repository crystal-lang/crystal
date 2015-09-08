.PHONY: all spec crystal doc clean

-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')
FLAGS := $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )
EXPORTS := $(if $(release),,CRYSTAL_CONFIG_PATH=`pwd`/src)
LLVM_EXT_DIR = src/llvm/ext
LLVM_EXT_OBJ = $(LLVM_EXT_DIR)/llvm_ext.o

all: crystal
spec: all_spec
	$(O)/all_spec
doc:
	$(BUILD_PATH) ./bin/crystal doc docs/main.cr

crystal: $(LLVM_EXT_OBJ) $(O)/crystal
all_spec: $(O)/all_spec

$(LLVM_EXT_OBJ): $(LLVM_EXT_DIR)/llvm_ext.cc
	$(CXX) -c -o $@ $< `llvm-config-3.6 --cxxflags`

$(O)/all_spec: $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build $(FLAGS) -o $@ spec/all_spec.cr

$(O)/crystal: $(SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) $(EXPORTS) ./bin/crystal build $(FLAGS) -o $@ src/compiler/crystal.cr

clean:
	rm -rf $(O)
	rm -rf ./doc
	rm -rf $(LLVM_EXT_OBJ)
