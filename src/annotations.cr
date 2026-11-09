# Indicates to the compiler that it should attempt to inline the annotated
# method whenever possible.
#
# ```
# @[AlwaysInline]
# def foo
#   1
# end
# ```
#
# This has no effect on yielding methods because they are already always inlined.
#
# May not be used together with `NoInline`.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `AlwaysInline`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#alwaysinline).
annotation AlwaysInline
end

# Indicates the calling convention of a `fun` or an entire `lib` definition.
#
# It expects a single positional argument with the name of the calling
# convention as `StringLiteral`.
#
# ```
# lib LibFoo
#   @[CallConvention("X86_StdCall")]
#   fun foo : Int32
# end
# ```
#
# The list of valid call conventions is:
#
# * `C` (the default)
# * `Fast`
# * `Cold`
# * `WebKit_JS`
# * `AnyReg`
# * `X86_StdCall`
# * `X86_FastCall`
#
# When applied directly to a `lib`, it sets the default calling convention for
# every `fun` declared within it that doesn't specify its own.
#
# See the [LLVM
# documentation](https://llvm.org/docs/LangRef.html#calling-conventions) for
# more details.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `CallConvention`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#callconvention).
annotation CallConvention
end

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
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Deprecated`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#deprecated).
annotation Deprecated
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
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Experimental`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#experimental).
annotation Experimental
end

# Marks a `struct` type for external use, allowing it to be used in lib
# declarations.
#
# This prevents the compiler from optimizing the layout of the struct, and
# ensures it matches the C ABI.
#
# ```
# @[Extern]
# struct MyStruct
#   property x = 0
#   property y = 0
# end
#
# lib MyLib
#   fun my_func(s : MyStruct) # would error without the Extern annotation
# end
# ```
#
# The `union: true` argument makes the struct behave like a C union, where all
# instance variables share the same memory location (this can be unsafe):
#
# ```
# @[Extern(union: true)]
# struct Int32OrChar
#   property int = 0
#   property char = '\0'
# end
#
# s = Int32OrChar.new
# s.char = 'A'
# s.int # => 65
# ```
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Extern`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#extern).
annotation Extern
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
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Flags`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#flags).
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
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Link`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#link).
annotation Link
end

# Indicates to the compiler that it should never inline the annotated method.
#
# ```
# @[NoInline]
# def foo
#   1
# end
# ```
#
# This has no effect if the method yields, since methods that yield are
# always inlined.
#
# May not be used together with `AlwaysInline`.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `NoInline`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#noinline).
annotation NoInline
end

# Marks a C `struct` or `union`, or an  `Extern` struct as
# packed.
#
# The alignment of a packed struct is one byte and there is no padding between
# fields.
#
# ```
# lib Foo
#   @[Packed]
#   struct Bar
#     x : Int8
#     y : Int32
#   end
# end
#
# sizeof(Foo::Bar) # => 5 (an unpacked struct would be 8)
#
# @[Extern]
# @[Packed]
# struct Bar
#   def initialize(@x : Int8, @y : Int32)
#   end
# end
#
# sizeof(Bar) # => 5 (an unpacked struct would be 8)
# ```
#
# This is typically only needed when interfacing with a C library that
# explicitly uses packed structs.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Packed`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#packed).
annotation Packed
end

# Marks a method or function as potentially raising an exception.
#
# This is usually not necessary for regular Crystal methods because the compiler
# knows which ones can raise.
#
# This annotation can indicate to the compiler that a C function invokes a
# user-provided callback that might raise, so it must generate the
# appropriate exception handling code around the call.
#
# ```
# lib LibFoo
#   @[Raises]
#   fun foo(callback : ->)
# end
# ```
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `Raises`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#raises).
annotation Raises
end

# Indicates that the annotated method or function can return twice.
#
# The C `setjmp` function is an example of a function that returns twice: once
# right after being called, and once again whenever the matching `longjmp` is
# invoked.
#
# The compiler disables some optimizations (like tail calls) in the caller of
# these functions.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `ReturnsTwice`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#returnstwice).
annotation ReturnsTwice
end

# The annotation allows to assume special CPU model/features for a method.
#
# It is similar to the `--cpu` and `--mattr` build arguments, but where the
# scope is limited to the annotated `def` or `fun`. It allows to compile a single
# executable, yet allow some optimized functions that will only run when
# available, such as specific SIMD instructions for example.
#
# CPU feature and model selections only accept values valid for the current
# target platform architecture.
#
# It is a semantic error to call a method with a feature requirement that is
# invalid for the current target architecture. Calls typically require macro
# guard clauses on top of runtime feature tests.
#
# For example:
#
# ```
# {% if flag?(:x86_64) %}
#   @[TargetFeature("+avx2")]
#   private def foo_avx2
#   end
#
#   private def cpu_supports_avx2?
#   end
# {% end %}
#
# private def foo_portable
# end
#
# def foo
#   {% if flag?(:x86_64) %}
#     return foo_avx2 if cpu_supports_avx2?
#   {% end %}
#   foo_portable
# end
# ```
#
# WARNING: When a method has been compiled with a feature and that feature is
# not supported at runtime, calling this method will result in an illegal
# instruction, and is undefined behaviour.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `TargetFeature`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#targetfeature).
annotation TargetFeature
end

# :nodoc:
#
# Marks a class variable or a C external variable as thread local.
# That means each thread gets its own separate storage for it.
#
# This annotation is used in the standard library to implement the runtime and
# shouldn't be needed or used outside of it.
#
# NOTE: The Crystal book has a section about [Built-in Annotations: `ThreadLocal`](https://crystal-lang.org/reference/syntax_and_semantics/annotations/built_in_annotations.html#threadlocal).
annotation ThreadLocal
end
