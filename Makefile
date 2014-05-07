.PHONY: all spec crystal clean

-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')

all: crystal
spec: all_spec
	$(O)/all_spec

crystal: $(O)/crystal
all_spec: $(O)/all_spec

$(O)/all_spec: $(SOURCES) $(SPEC_SOURCES)
	@mkdir -p $(O)
	./bin/crystal -o $@ spec/all_spec.cr

$(O)/crystal: $(SOURCES)
	@mkdir -p $(O)
	./bin/crystal $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )-o $@ src/compiler/crystal.cr

clean:
	rm -rf $(O)
