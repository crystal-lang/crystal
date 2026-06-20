# Entries to this file should only be ordered if macros are involved -
# macros need to be defined before they are used.
# A first compiler pass gathers all classes and methods, removing the
# requirement to place these in load order.
#
# When adding new files, use alpha-sort when possible. Make sure
# to also add them to `docs_main.cr` if their content needs to
# appear in the API docs.

# This list requires ordered statements
require "lib_c"
require "macros"
require "object"
require "crystal/once"
require "comparable"
require "exception"
require "iterable"
require "iterator"
require "steppable"
require "indexable"
# `Tuple` includes `Indexable(Union(*T))`. It must be required here, before any
# file that can register a tuple as an including type of a module (e.g. `env`'s
# `extend Enumerable(...)`), otherwise that early instantiation runs with an
# incomplete parent list and is missing from the module's including types,
# breaking `as Enumerable(T)` upcasts (#8771).
require "tuple"
require "named_tuple"
require "string"
require "number"
require "primitives"

# Alpha-sorted list
require "annotations"
require "array"
require "atomic"
require "base64"
require "bool"
require "box"
require "char"
require "char/reader"
require "class"
require "concurrent"
require "crystal/compiler_rt"
require "crystal/main"
require "deque"
require "dir"
require "enum"
require "enumerable"
require "env"
require "errno"
require "winerror"
require "wasi_error"
require "file"
require "float"
require "gc"
require "hash"
require "int"
require "intrinsics"
require "io"
require "kernel"
require "math/math"
require "mutex"
require "nil"
require "humanize"
require "path"
require "pointer"
require "pretty_print"
require "proc"
require "process"
require "raise"
require "random"
require "range"
require "reference"
require "reference_storage"
require "regex"
require "set"
{% unless flag?(:wasm32) %}
  require "signal"
{% end %}
require "slice"
require "static_array"
require "struct"
require "symbol"
require "system"
require "crystal/system/thread"
require "time"
require "unicode"
require "union"
require "va_list"
require "value"
