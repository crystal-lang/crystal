# This is the main file used for generating docs for the standard library.
# It, for example, doesn't include API for the compiler, but does include
# the fictitious API for the Crystal::Macros module.

require "./annotations"
require "./compiler/crystal/macros"

require "./*"
require "./big/**"
require "./compress/**"
require "./crypto/**"
require "./crystal/syntax_highlighter/*"
require "./digest/**"
require "./fiber/**"
require "./gc/**"
require "./http/**"
require "./io/**"
require "./log/**"
require "./math/**"
require "./random/**"
require "./spec/helpers/**"
require "./string/**"
require "./system/**"
require "./uri/**"
require "./uuid/**"
