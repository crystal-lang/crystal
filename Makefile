all: crystal
spec: crystal_spec
	./crystal_spec

crystal: $(wildcard bootstrap/crystal/**) $(wildcard std/**) $(wildcard lib/**)
	crystal bootstrap/crystal.cr -o crystal_new

crystal_spec: $(wildcard bootstrap/crystal/**) $(wildcard std/**) $(wildcard lib/**) $(wildcard bootstrap/spec/**)
	crystal bootstrap/spec/crystal_spec.cr
