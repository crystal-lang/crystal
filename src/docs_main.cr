# This is the main file used for generating docs for the standard library.
# It, for example, doesn't include API for the compiler, but does include
# the fictitious API for the Crystal::Macros module.

require "./annotations"
require "./compiler/crystal/macros"

require "./*"
require "./compress/**"
require "./crypto/**"
require "./crystal/syntax_highlighter/*"
require "./digest/**"
require "./gc/**"
require "./http/**"
require "./io/**"
require "./log/spec"
require "./math/**"
require "./random/**"
require "./spec/**"
require "./string/**"
require "./system/**"
require "./uri/**"
require "./uuid/**"
