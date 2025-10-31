# This annotation marks features as deprecated.
#
# It can annotate methods, macros, types, constants, aliases and method parameters.
#
# It receives an optional `StringLiteral` as single argument containing a
# deprecation notice.
#
# ```
# @[Deprecated("Use `#bar` instead")]
# def foo
# end
#
# @[Deprecated("Here may be dragons")]
# class Foo
# end
#
# def foo(bar, @[Deprecated("Do not try this at home")] baz)
# end
# ```
#
# Deprecations are shown in the API docs and the compiler prints a warning when
# using a deprecated feature.
#
# Deprecated types only trigger a warning when they are actually _used_ (e.g.
# calling a class method), not when they're just part of type restriction, for
# example.
# Deprecated parameters only trigger a warning when the particular parameter is
# passed in a call. Calls without this parameter are unaffected.
annotation Deprecated
end

# An enum can be marked with `@[Flags]`. This changes the default values.
# The first constant's value is 1, and successive constants are multiplied by 2.
#
# ```
# @[Flags]
# enum IOMode
#   Read  # 1
#   Write # 2
#   Async # 4
# end
#
# (IOMode::Write | IOMode::Async).value # => 6
# (IOMode::Write | IOMode::Async).to_s  # => "Write | Async"
# ```
annotation Flags
end

# A `lib` can be marked with `@[Link(lib : String, *, ldflags : String, static : Bool, framework : String, pkg_config : String, wasm_import_module : String, dll : String)]`
# to declare the library that should be linked when compiling the program.
#
# At least one of the *lib*, *ldflags*, *framework* arguments needs to be specified.
#
# `@[Link(ldflags: "-lpcre")]` will pass `-lpcre` straight to the linker.
#
# `@[Link("pcre")]` will lookup for a shared library.
# 1. will lookup `pcre` using `pkg-config`, if not found
# 2. will pass `-lpcre` to the linker.
#
# `@[Link("pcre", pkg_config: "libpcre")]` will lookup for a shared library.
# 1. will lookup `libpcre` using `pkg-config`, if not found
# 2. will lookup `pcre` using `pkg-config`, if not found
# 3. will pass `-lpcre` to the linker.
#
# `@[Link(framework: "Cocoa")]` will pass `-framework Cocoa` to the linker.
#
# `@[Link(dll: "gc.dll")]` will copy `gc.dll` to any built program. The DLL name
# must use `.dll` as its file extension and cannot contain any directory
# separators. The actual DLL is searched among `CRYSTAL_LIBRARY_PATH`, the
# compiler's own directory, and `PATH` in that order; a warning is printed if
# the DLL isn't found, although it might still run correctly if the DLLs are
# available in other DLL search paths on the system.
#
# When an `-l` option is passed to the linker, it will lookup the libraries in
# paths passed with the `-L` option. Any paths in `CRYSTAL_LIBRARY_PATH` are
# added by default. Custom paths can be passed using `ldflags`:
# `@[Link(ldflags: "-Lvendor/bin")]`.
annotation Link
end

# This annotation marks methods, classes, constants, and macros as experimental.
#
# Experimental features are subject to change or be removed despite the
# [https://semver.org/](https://semver.org/) guarantees.
#
# ```
# @[Experimental("Join discussion about this topic at ...")]
# def foo
# end
# ```
annotation Experimental
end
