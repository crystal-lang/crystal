# This annotation marks methods, classes, constants, and macros as deprecated.
#
# It receives an optional `StringLiteral` as single argument containing a deprecation notice.
#
# ```
# @[Deprecated("Use `#bar` instead")]
# def foo
# end
# ```
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

# A `lib` can be marked with `@[Link(lib : String, *, ldflags : String, framework : String, pkg_config : String)]`
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
