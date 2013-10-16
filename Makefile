all: crystal
spec: crystal_spec
	./crystal_spec

crystal: $(wildcard bootstrap/crystal/**) $(wildcard std/**) $(wildcard lib/**)
	bin/crystal bootstrap/crystal.cr

crystal_spec: $(wildcard bootstrap/crystal/**) $(wildcard std/**) $(wildcard lib/**) $(wildcard bootstrap/spec/**)
	bin/crystal bootstrap/spec/crystal_spec.cr
