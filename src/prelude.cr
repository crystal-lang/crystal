# Entries to this file should only be ordered if macros are involved -
# macros need to be defined before they are used.
# A first compiler pass gathers all classes and methods, removing the
# requirement to place these in load order.
#
# When adding new files, use alpha-sort when possible. Make sure
# to also add them to `docs_main.cr` if their content needs to
# appear in the API docs.

# This list requires ordered statements
require "crystal/once"
require "lib_c"
require "macros"
require "object"
require "comparable"
{% if flag?(:win32) %}
  require "windows_stubs"
{% end %}
require "exception"
require "iterable"
require "iterator"
require "steppable"
require "indexable"
require "string"
require "number"

# Alpha-sorted list
require "annotations"
require "array"
require "atomic"
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
require "file"
require "float"
require "gc"
require "hash"
require "int"
require "intrinsics"
require "io"
require "kernel"
require "math/math"
{% unless flag?(:win32) %}
  require "mutex"
{% end %}
require "named_tuple"
require "nil"
require "humanize"
require "path"
require "pointer"
require "pretty_print"
require "primitives"
require "proc"
require "process"
require "raise"
require "random"
require "range"
require "reference"
require "regex"
require "set"
{% unless flag?(:win32) %}
  require "signal"
{% end %}
require "slice"
require "static_array"
require "struct"
require "symbol"
require "system"
require "crystal/system/thread"
require "time"
require "tuple"
require "unicode"
require "union"
require "va_list"
require "value"
