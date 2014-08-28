.PHONY: all spec crystal clean gc

-include Makefile.local # for optional local options e.g. threads

O := .build
SOURCES := $(shell find src -name '*.cr')
SPEC_SOURCES := $(shell find spec -name '*.cr')

all: crystal gc
gc: $(O)/libgc.a
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

$(O)/libgc.a:
	git clone --depth 1 git://github.com/ivmai/bdwgc.git $(O)/bdwgc
	git clone --depth 1 git://github.com/ivmai/libatomic_ops.git $(O)/bdwgc/libatomic_ops
	cd $(O)/bdwgc && autoreconf -vif
	cd $(O)/bdwgc && automake --add-missing
	cd $(O)/bdwgc && ./configure
	cd $(O)/bdwgc && make
	cp $(O)/bdwgc/.libs/libgc.a $(O)/

clean:
	rm -rf $(O)
