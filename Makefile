SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')

all: crystal
spec: all_spec
	./all_spec

crystal: $(SOURCES)
	@if [ -x crystal ]; then \
		echo mv crystal crystal-old; \
		mv crystal crystal-old; \
		echo ./crystal-old src/compiler/crystal.cr; \
		./crystal-old src/compiler/crystal.cr; \
	else \
		echo bin/crystal src/compiler/crystal.cr; \
	  bin/crystal src/compiler/crystal.cr; \
	fi

all_spec: $(SOURCES) $(SPEC_SOURCES)
	@if [ -x crystal ]; then \
		echo ./crystal spec/all_spec.cr; \
		./crystal spec/all_spec.cr; \
	else \
		echo bin/crystal spec/all_spec.cr; \
	  bin/crystal spec/all_spec.cr; \
	fi
