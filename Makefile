.PHONY: all spec crystal clean

-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')
FLAGS := $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )
EXPORTS := $(if $(release),,CRYSTAL_CONFIG_PATH=`pwd`/src)
ifeq (Darwin,$(shell uname))
	BUILD_PATH := PATH=`brew --prefix llvm`/bin:$$PATH LIBRARY_PATH=`brew --prefix crystal`/embedded/lib
endif

all: crystal
spec: all_spec
	$(O)/all_spec

crystal: $(O)/crystal
all_spec: $(O)/all_spec

$(O)/all_spec: $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) ./bin/crystal build -o $@ spec/all_spec.cr

$(O)/crystal: $(SOURCES)
	@mkdir -p $(O)
	$(BUILD_PATH) $(EXPORTS) ./bin/crystal build $(FLAGS) -o $@ src/compiler/crystal.cr

clean:
	rm -rf $(O)
