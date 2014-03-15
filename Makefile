.PHONY: all spec crystal clean

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')

all: crystal
spec: all_spec
	./all_spec

crystal: $(O)/crystal

all_spec: $(SOURCES) $(SPEC_SOURCES)
	./bin/crystal spec/all_spec.cr

$(O)/crystal: $(SOURCES)
	@mkdir -p $(O)
	./bin/crystal $(if $(release),--release) $(if $(stats),-stats) -o $@ src/compiler/crystal.cr

clean:
	rm -rf $(O)
