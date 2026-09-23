{%
  min_compiler_version = "1.13.0"
  if compare_versions(Crystal::VERSION, min_compiler_version) < 0
    @top_level.warning <<-TXT
      This compiler release at version #{Crystal::VERSION.id} is no longer supported.
      Please upgrade to at least Crystal #{min_compiler_version.id}.

      Learn about the forward compatibility policy at https://crystal-lang.org/reference/project/release-policy.html#forward-compatibility
      TXT
  end
%}

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
require "named_tuple"
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
require "tuple"
require "unicode"
require "union"
require "va_list"
require "value"
