# This is a spec entry point to run all specs related to syntax (parsing, formatting, tools).

require "./compiler/lexer/**"
require "./compiler/parser/**"
require "./compiler/formatter/**"

require "./compiler/crystal/tools/doc_spec.cr"
require "./compiler/crystal/tools/doc/**"
require "./compiler/crystal/tools/flags_spec.cr"
require "./compiler/crystal/tools/format_spec.cr"

require "./std/crystal/syntax_highlighter/**"
