# The `Macros` module is a fictitious module used to document macros
# and macro methods.
#
# You can invoke a **fixed subset** of methods on AST nodes at compile-time. These methods
# are documented on the classes in this module. Additionally, methods of the
# `Macros` module are top-level methods that you can invoke, like `puts` and `run`.
module Crystal::Macros
  # Compares two [semantic versions](http://semver.org/).
  # Returns `-1` if `v1 < v2`, `0` if `v1 == v2` and `1` if `v1 > v2`.
  #
  # ```
  # {{ compare_versions("1.10.0", "1.2.0") }} # => 1
  # ```
  def compare_versions(v1 : StringLiteral, v2 : StringLiteral) : NumberLiteral
  end

  # Outputs the current macro's buffer to the standard output. Useful for debugging
  # a macro to see what's being generated.
  #
  # By default, the output is tried to be formatted using Crystal's
  # formatter, but you can disable this by passing `false` to this method.
  def debug(format = true) : Nop
  end

  # Gets the value of an environment variable at compile-time, or `nil` if it doesn't exist.
  def env(name) : StringLiteral | NilLiteral
  end

  # Returns whether a [compile-time flag](https://crystal-lang.org/docs/syntax_and_semantics/compile_time_flags.html) is set.
  #
  # ```
  # {{ flag?(:x86_64) }} # true or false
  # ```
  def flag?(name) : BoolLiteral
  end

  # Prints an AST node at compile-time. Useful for debugging macros.
  def puts(expression) : Nop
  end

  # Same as `puts`.
  def p(expression) : Nop
  end

  # Executes a system command and returns the output as a `MacroId`.
  # Gives a compile-time error if the command failed to execute.
  def `(command) : MacroId
  end

  # ditto
  def system(command) : MacroId
  end

  # Gives a compile-time error with the given *message*.
  def raise(message) : NoReturn
  end

  # Compiles and execute a Crystal program and returns its output
  # as a `MacroId`.
  #
  # The file denote by *filename* must be a valid Crystal program.
  # This macro invocation passes *args* to the program as regular
  # program arguments. The program must output a valid Crystal expression.
  # This output is the result of this macro invocation, as a `MacroId`.
  #
  # The `run` macro is useful when the subset of available macro methods
  # are not enough for your purposes and you need something more powerful.
  # With `run` you can read files at compile time, connect to the internet
  # or to a database.
  #
  # A simple example:
  #
  # ```
  # # read.cr
  # puts File.read(ARGV[0])
  # ```
  #
  # ```
  # # main.cr
  # macro read_file_at_compile_time(filename)
  #   {{ run("./read", filename).stringify }}
  # end
  #
  # puts read_file_at_compile_time("some_file.txt")
  # ```
  #
  # The above generates a program that will have the contents of `some_file.txt`.
  # The file, however, is read at compile time and will not be needed at runtime.
  #
  # NOTE: the compiler is allowed to cache the executable generated for
  # *filename* and only recompile it if any of the files it depends on changes
  # (their modified time). This is why it's **strongly discouraged** to use a program
  # for `run` that changes in subsequent compilations (for example, if it executes
  # shell commands at compile time, or other macro run programs). It's also strongly
  # discouraged to have a macro run program take a lot of time, because this will
  # slow down compilation times. Reading files is OK, opening an HTTP connection
  # at compile-time will most likely result if very slow compilations.
  def run(filename, *args) : MacroId
  end

  # Skips the rest of the file from which it is executed.
  # Typical usage is to skip files that have platform specific code,
  # without having to surround the most relevant code in `{% if flag?(...) %} ... {% end %}` macro blocks.
  #
  # Example:
  #
  # ```
  # # sth_for_osx.cr
  # {% skip_file unless flag?(:darwin) %}
  #
  # # Class FooForMac will only be defined if we're compiling on OS X
  # class FooForMac
  # end
  # ```
  def skip_file : Nop
  end

  # This is the base class of all AST nodes. This methods are
  # available to all AST nodes.
  abstract class ASTNode
    # Returns this node as a `MacroId`. Useful when you need an identifier
    # out of a `StringLiteral`, `SymbolLiteral`, `Var` or `Call`.
    #
    # ```
    # macro define_method(name, content)
    #   def {{name.id}}
    #     {{content}}
    #   end
    # end
    #
    # define_method :foo, 1
    # define_method "bar", 2
    # define_method baz, 3
    #
    # puts foo # => prints 1
    # puts bar # => prints 2
    # puts baz # => prints 3
    # ```
    def id : MacroId
    end

    # Returns a `StringLiteral` that contains this node's textual representation.
    # Note that invoking stringify on a string literal will return a `StringLiteral`
    # that contains a string literal.
    #
    # ```
    # macro test
    #   {{ "foo".stringify }}
    # end
    #
    # puts test # prints "foo" (including the double quotes)
    # ```
    def stringify : StringLiteral
    end

    # Returns a `SymbolLiteral` that contains this node's textual representation.
    #
    # ```
    # {{ "foo".id.symbolize }} # => :foo
    # ```
    def symbolize : SymbolLiteral
    end

    # Returns a `StringLiteral` that contains this node's name.
    #
    # ```
    # macro test
    #   {{ "foo".class_name }}
    # end
    #
    # puts test # => prints StringLiteral
    # ```
    def class_name : StringLiteral
    end

    # Returns the filename where this node is located.
    # Might return `nil` if the location is not known.
    def filename : StringLiteral | NilLiteral
    end

    # Returns the line number where this node begins.
    # Might return `nil` if the location is not known.
    #
    # The first line number in a file is 1.
    def line_number : StringLiteral | NilLiteral
    end

    # Returns the column number where this node begins.
    # Might return `nil` if the location is not known.
    #
    # The first column number in a line is `1`.
    def column_number : StringLiteral | NilLiteral
    end

    # Returns the line number where this node ends.
    # Might return `nil` if the location is not known.
    #
    # The first line number in a file is `1`.
    def end_line_number : StringLiteral | NilLiteral
    end

    # Returns the column number where this node ends.
    # Might return `nil` if the location is not known.
    #
    # The first column number in a line is `1`.
    def end_column_number : StringLiteral | NilLiteral
    end

    # Returns `true` if this node's textual representation is the same as
    # the *other* node.
    def ==(other : ASTNode) : BoolLiteral
    end

    # Returns `true` if this node's textual representation is not the same as
    # the *other* node.
    def !=(other : ASTNode) : BoolLiteral
    end

    # Gives a compile-time error with the given *message*. This will
    # highlight this node in the error message.
    def raise(message) : NoReturn
    end
  end

  # The empty node. Similar to a `NilLiteral` but its textual representation
  # is the empty string. This corresponds, for example, to the missing `else` branch of
  # an `if` without an `else`.
  class Nop < ASTNode
  end

  # The nil literal.
  class NilLiteral < ASTNode
  end

  # A bool literal.
  class BoolLiteral < ASTNode
  end

  # Any number literal.
  class NumberLiteral < ASTNode
    # Compares this node's value to another node's value.
    def <(other : NumberLiteral) : BoolLiteral
    end

    # ditto
    def <=(other : NumberLiteral) : BoolLiteral
    end

    # ditto
    def >(other : NumberLiteral) : BoolLiteral
    end

    # ditto
    def >=(other : NumberLiteral) : BoolLiteral
    end

    # ditto
    def <=>(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#+`
    def +(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#-`
    def -(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#*`
    def *(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#/`
    def /(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#%`
    def %(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#&`
    def &(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#|`
    def |(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#^`
    def ^(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#**`
    def **(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#<<`
    def <<(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#>>`
    def >>(other : NumberLiteral) : NumberLiteral
    end

    # Same as `Number#+`
    def + : NumberLiteral
    end

    # Same as `Number#-`
    def - : NumberLiteral
    end

    # Same as `Number#~`
    def ~ : NumberLiteral
    end

    # The type of the literal: `:i32`, `:u16`, `:f32`, `:f64`, etc.
    def kind : SymbolLiteral
    end
  end

  # A character literal.
  class CharLiteral < ASTNode
    # Returns a `MacroId` for this character's contents.
    def id : MacroId
    end
  end

  # A string literal.
  class StringLiteral < ASTNode
    # Returns a `MacroId` for this string's contents.
    def id : MacroId
    end

    # Similar to `String#[]`.
    def [](range : RangeLiteral) : StringLiteral
    end

    # Similar to `String#=~`.
    def =~(range : RegexLiteral) : BoolLiteral
    end

    # Similar to `String#>`
    def >(other : StringLiteral | MacroId) : BoolLiteral
    end

    # Similar to `String#<`
    def <(other : StringLiteral | MacroId) : BoolLiteral
    end

    # Similar to `String#+`.
    def +(other : StringLiteral | CharLiteral) : StringLiteral
    end

    # Similar to `String#camelcase`.
    def camelcase : StringLiteral
    end

    # Similar to `String#capitalize`.
    def capitalize : StringLiteral
    end

    # Similar to `String#chars`.
    def chars : ArrayLiteral(CharLiteral)
    end

    # Similar to `String#chomp`.
    def chomp : StringLiteral
    end

    # Similar to `String#downcase`.
    def downcase : StringLiteral
    end

    # Similar to `String#empty?`.
    def empty? : BoolLiteral
    end

    # Similar to `String#ends_with?`.
    def ends_with?(other : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#gsub`.
    def gsub(regex : RegexLiteral, replacement : StringLiteral) : StringLiteral
    end

    # Similar to `String#includes?`.
    def includes?(search : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#size`.
    def size : NumberLiteral
    end

    # Similar to `String#lines`.
    def lines : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#split`.
    def split : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#split`.
    def split(node : ASTNode) : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#starts_with?`.
    def starts_with?(other : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#strip`.
    def strip : StringLiteral
    end

    # Similar to `String#to_i`.
    def to_i(base = 10)
    end

    # Similar to `String#tr`.
    def tr(from : StringLiteral, to : StringLiteral) : StringLiteral
    end

    # Similar to `String#underscore`.
    def underscore : StringLiteral
    end

    # Similar to `String#upcase`.
    def upcase : StringLiteral
    end
  end

  # An interpolated string like `"Hello, #{name}!"`.
  class StringInterpolation < ASTNode
    # Returns a list of expressions that comprise the interpolated string.
    #
    # These alternate between `StringLiteral` for the plaintext parts and
    # `ASTNode`s of any type for the interpolated expressions.
    def expressions : ArrayLiteral(ASTNode)
    end
  end

  # A symbol literal.
  class SymbolLiteral < ASTNode
    # Returns a `MacroId` for this symbol's contents.
    def id : MacroId
    end

    # Similar to `String#[]`.
    def [](range : RangeLiteral) : SymbolLiteral
    end

    # Similar to `String#=~`.
    def =~(range : RegexLiteral) : BoolLiteral
    end

    # Similar to `String#+`.
    def +(other : StringLiteral | CharLiteral) : SymbolLiteral
    end

    # Similar to `String#capitalize`.
    def capitalize : SymbolLiteral
    end

    # Similar to `String#chars`.
    def chars : ArrayLiteral(CharLiteral)
    end

    # Similar to `String#chomp`.
    def chomp : SymbolLiteral
    end

    # Similar to `String#downcase`.
    def downcase : SymbolLiteral
    end

    # Similar to `String#empty?`.
    def empty? : BoolLiteral
    end

    # Similar to `String#ends_with?`.
    def ends_with?(other : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#gsub`.
    def gsub(regex : RegexLiteral, replacement : StringLiteral) : SymbolLiteral
    end

    # Similar to `String#includes?`.
    def includes?(search : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#size`.
    def size : NumberLiteral
    end

    # Similar to `String#lines`.
    def lines : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#split`.
    def split : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#split`.
    def split(node : ASTNode) : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#starts_with?`.
    def starts_with?(other : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#strip`.
    def strip : SymbolLiteral
    end

    # Similar to `String#tr`.
    def tr(from : StringLiteral, to : StringLiteral) : SymbolLiteral
    end

    # Similar to `String#upcase`.
    def upcase : SymbolLiteral
    end
  end

  # An array literal.
  class ArrayLiteral < ASTNode
    # Similar to `Enumerable#any?`
    def any?(&block) : BoolLiteral
    end

    # Similar to `Enumerable#all?`
    def all?(&block) : BoolLiteral
    end

    # Returns a `MacroId` with all of this array's elements joined
    # by commas.
    #
    # If *trailing_string* is given, it will be appended to
    # the result unless this array is empty. This lets you
    # splat an array and optionally write a trailing comma
    # if needed.
    def splat(trailing_string : StringLiteral = nil) : MacroId
    end

    # Similar to `Array#empty?`
    def empty? : BoolLiteral
    end

    # Similar to `Enumerable#find`
    def find(&block) : ASTNode | NilLiteral
    end

    # Similar to `Array#first`, but returns a `NilLiteral` if the array is empty.
    def first : ASTNode | NilLiteral
    end

    # Similar to `Enumerable#includes?(obj)`.
    def includes?(node : ASTNode) : BoolLiteral
    end

    # Similar to `Enumerable#join`
    def join(separator) : StringLiteral
    end

    # Similar to `Array#last`, but returns a `NilLiteral` if the array is empty.
    def last : ASTNode | NilLiteral
    end

    # Similar to `Array#size`
    def size : NumberLiteral
    end

    # Similar to `Enumerable#map`
    def map(&block) : ArrayLiteral
    end

    # Similar to `Enumerable#select`
    def select(&block) : ArrayLiteral
    end

    # Similar to `Enumerable#reject`
    def reject(&block) : ArrayLiteral
    end

    # Similar to `Enumerable#reduce`
    def reduce(&block) : ASTNode
    end

    # Similar to `Array#shuffle`
    def shuffle : ArrayLiteral
    end

    # Similar to `Array#sort`
    def sort : ArrayLiteral
    end

    # Similar to `Array#uniq`
    def uniq : ArrayLiteral
    end

    # Similar to `Array#[]`, but returns `NilLiteral` on out of bounds.
    def [](index : NumberLiteral) : ASTNode
    end

    # Similar to `Array#[]=`.
    def []=(index : NumberLiteral, value : ASTNode)
    end

    # Similar to `Array#+`.
    def +(other : ArrayLiteral) : ArrayLiteral
    end

    # Returns the type specified at the end of the array literal, if any.
    #
    # This refers to the part after brackets in `[] of String`.
    def of : ASTNode | Nop
    end

    # Returns the type that receives the items of the array.
    #
    # This refers to the part before brackets in `MyArray{1, 2, 3}`
    def type : Path | Nop
    end
  end

  # A hash literal.
  class HashLiteral < ASTNode
    # Similar to `Hash#empty?`
    def empty? : BoolLiteral
    end

    # Similar to `Hash#keys`
    def keys : ArrayLiteral
    end

    # Similar to `Hash#size`
    def size : NumberLiteral
    end

    # Similar to `Hash#to_a`
    def to_a : ArrayLiteral(TupleLiteral)
    end

    # Similar to `Hash#values`
    def values : ArrayLiteral
    end

    # Similar to `Hash#map`
    def map : ArrayLiteral
    end

    # Similar to `Hash#[]`
    def [](key : ASTNode) : ASTNode
    end

    # Similar to `Hash#[]=`
    def []=(key : ASTNode) : ASTNode
    end

    # Returns the type specified at the end of the Hash literal, if any.
    #
    # This refers to the key type after brackets in `{} of String => Int32`.
    def of_key : ASTNode | Nop
    end

    # Returns the type specified at the end of the Hash literal, if any.
    #
    # This refers to the value type after brackets in `{} of String => Int32`.
    def of_value : ASTNode | Nop
    end

    # Returns the type that receives the items of the array.
    #
    # This refers to the part before brackets in `MyHash{'a' => 1, 'b' => 2}`
    def type : Path | Nop
    end

    # Returns a `MacroId` with all of this hash elements joined
    # by commas.
    #
    # If *trailing_string* is given, it will be appended to
    # the result unless this hash is empty. This lets you
    # splat a hash and optionally write a trailing comma
    # if needed.
    def double_splat(trailing_string : StringLiteral = nil) : MacroId
    end
  end

  # A named tuple literal.
  class NamedTupleLiteral < ASTNode
    # Similar to `NamedTuple#empty?`
    def empty? : BoolLiteral
    end

    # Similar to `NamedTuple#keys`
    def keys : ArrayLiteral
    end

    # Similar to `NamedTuple#size`
    def size : NumberLiteral
    end

    # Similar to `NamedTuple#to_a`
    def to_a : ArrayLiteral(TupleLiteral)
    end

    # Similar to `NamedTuple#values`
    def values : ArrayLiteral
    end

    # Similar to `NamedTuple#map`
    def map : ArrayLiteral
    end

    # Similar to `HashLiteral#double_splat`
    def double_splat(trailing_string : StringLiteral = nil) : MacroId
    end

    # Similar to `NamedTuple#[]`
    def [](key : ASTNode) : ASTNode
    end

    # Adds or replaces a key.
    def []=(key : ASTNode) : ASTNode
    end
  end

  # A range literal.
  class RangeLiteral < ASTNode
    # Similar to `Range#begin`
    def begin : ASTNode
    end

    # Similar to `Range#end`
    def end : ASTNode
    end

    # Similar to `Range#excludes_end?`
    def excludes_end? : ASTNode
    end

    # Similar to `Enumerable#map` for a `Range`.
    # Only works on ranges of `NumberLiteral`s considered as integers.
    def map : ArrayLiteral
    end

    # Similar to `Enumerable#to_a` for a `Range`.
    # Only works on ranges of `NumberLiteral`s considered as integers.
    def to_a : ArrayLiteral
    end
  end

  # A regular expression literal.
  class RegexLiteral < ASTNode
    # Similar to `Regex#source`.
    def source : StringLiteral | StringInterpolation
    end

    # Similar to `Regex#options`,
    # but returns an array of symbols such as `[:i, :m, :x]`
    def options : ArrayLiteral(SymbolLiteral)
    end
  end

  # A tuple literal.
  #
  # It's macro methods are the same as `ArrayLiteral`
  class TupleLiteral < ASTNode
  end

  # A fictitious node representing a variable or instance
  # variable, together with type information.
  class MetaVar < ASTNode
    # Returns the name of this variable.
    def name : MacroId
    end

    # Returns the type of this variable, if known, or `nil`.
    def type : TypeNode | NilLiteral
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    # Returns this var's name as a `MacroId`.
    def id : MacroId
    end
  end

  # A code block.
  class Block < ASTNode
    # Returns the block's body, if any.
    def body : ASTNode
    end

    # Returns the blocks arguments.
    def args : ArrayLiteral(MacroId)
    end

    # Returns the index of the argument with a *splat, if any.
    def splat_index : NumberLiteral | NilLiteral
    end
  end

  # A group of expressions.
  class Expressions < ASTNode
    # Returns the list of expressions in this node
    def expressions : ArrayLiteral(ASTNode)
    end
  end

  # A method call.
  class Call < ASTNode
    # Returns this call's name as a `MacroId`.
    def id : MacroId
    end

    # Returns the method name of this call.
    def name : MacroId
    end

    # Returns this call's receiver, if any.
    def receiver : ASTNode | Nop
    end

    # Returns this call's arguments.
    def args : ArrayLiteral
    end

    # Returns this call's named arguments.
    def named_args : ArrayLiteral(NamedArgument)
    end

    # Returns this call's block, if any.
    def block : Block | Nop
    end

    # Returns this call's block argument, if any
    def block_arg : ASTNode | Nop
    end
  end

  # A call's named argument.
  class NamedArgument < ASTNode
    # Returns this named argument name.
    def name : MacroId
    end

    # Returns this named argument value.
    def value : ASTNode
    end
  end

  # An if expression.
  class If < ASTNode
    # Returns this if's condition.
    def cond : ASTNode
    end

    # Returns this if's `then` clause's body.
    def then : ASTNode
    end

    # Returns this if's `else` clause's body.
    def else : ASTNode
    end
  end

  # class Unless < ASTNode
  # end

  # Assign expression.
  class Assign < ASTNode
    # Returns the target assigned to.
    def target : ASTNode
    end

    # Returns the value that is being assigned.
    def value : ASTNode
    end
  end

  # Multiple assign expression.
  class MultiAssign < ASTNode
    # Returns the targets assigned to.
    def targets : ArrayLiteral(ASTNode)
    end

    # Returns the values that are being assigned.
    def values : ArrayLiteral(ASTNode)
    end
  end

  # An instance variable.
  class InstanceVar < ASTNode
    # Returns the name of this variable.
    def name : MacroId
    end
  end

  # Access to an instance variable, e.g. `obj.@var`.
  class ReadInstanceVar < ASTNode
    # Returns the object whose variable is being accessed.
    def obj : ASTNode
    end

    # Returns the name of the instance variable being accessed.
    def name : MacroId
    end
  end

  # A class variable.
  class ClassVar < ASTNode
    # Returns the name of this variable.
    def name : MacroId
    end
  end

  # A global variable.
  class Global < ASTNode
    # Returns the name of this variable.
    def name : MacroId
    end
  end

  # A binary expression like `And` and `Or`.
  abstract class BinaryOp < ASTNode
    # Returns the left hand side of this node.
    def left : ASTNode
    end

    # Returns the left hand side of this node.
    def right : ASTNode
    end
  end

  # An `&&` (and) expression
  class And < BinaryOp
  end

  # An `||` (or) expression
  class Or < BinaryOp
  end

  # A def argument.
  class Arg < ASTNode
    # Returns the external name of this argument.
    #
    # For example, for `def write(to file)` returns `to`.
    def name : MacroId
    end

    # Returns the internal name of this argument.
    #
    # For example, for `def write(to file)` returns `file`.
    def internal_name : MacroId
    end

    # Returns the default value of this argument, if any.
    def default_value : ASTNode | Nop
    end

    # Returns the type restriction of this argument, if any.
    def restriction : ASTNode | Nop
    end
  end

  # class ProcNotation < ASTNode
  # end

  # A method definition.
  class Def < ASTNode
    # Returns the name of this method.
    def name : MacroId
    end

    # Returns the arguments of this method.
    def args : ArrayLiteral(Arg)
    end

    # Returns the index of the argument with a *splat, if any.
    def splat_index : NumberLiteral | NilLiteral
    end

    # Returns the double splat argument, if any.
    def double_splat : Arg | Nop
    end

    # Returns the block argument, if any.
    def block_arg : Arg | Nop
    end

    # Returns the return type of the method, if specified.
    def return_type : ASTNode | Nop
    end

    # Returns the body of this method.
    def body : ASTNode
    end

    # Returns the receiver (for example `self`) of this method definition,
    # or `Nop` if not specified.
    def receiver : ASTNode | Nop
    end

    # Returns the visibility of this def: `:public`, `:protected` or `:private`.
    def visibility : SymbolLiteral
    end
  end

  # A macro definition.
  class Macro < ASTNode
    # Returns the name of this macro.
    def name : MacroId
    end

    # Returns the arguments of this macro.
    def args : ArrayLiteral(Arg)
    end

    # Returns the index of the argument with a *splat, if any.
    def splat_index : NumberLiteral | NilLiteral
    end

    # Returns the double splat argument, if any.
    def double_splat : Arg | Nop
    end

    # Returns the block argument, if any.
    def block_arg : Arg | Nop
    end

    # Returns the body of this macro.
    def body : ASTNode
    end

    # Returns the visibility of this macro: `:public`, `:protected` or `:private`.
    def visibility : SymbolLiteral
    end
  end

  # An unary expression
  abstract class UnaryExpression < ASTNode
    # Returns the expression that this unary operation is applied to.
    def exp : ASTNode
    end
  end

  # An unary `not` (`!`).
  class Not < UnaryExpression
  end

  # A `pointerof` expression.
  class PointerOf < UnaryExpression
  end

  # A `sizeof` expression.
  class SizeOf < UnaryExpression
  end

  # An `instance_sizeof` expression.
  class InstanceSizeOf < UnaryExpression
  end

  # An `out` expression.
  class Out < UnaryExpression
  end

  # A visibility modifier
  class VisibilityModifier < ASTNode
    # Returns the visibility of this modifier: `:public`, `:protected` or `:private`.
    def visibility : SymbolLiteral
    end

    # Returns the expression that the modifier is applied to.
    def exp : ASTNode
    end
  end

  # An `.is_a?` or `.nil?` call.
  class IsA < ASTNode
    # Returns this call's receiver.
    def receiver : ASTNode
    end

    # Returns this call's argument.
    def arg : ASTNode
    end
  end

  # A `.responds_to?` call.
  class RespondsTo < ASTNode
    # Returns this call's receiver.
    def receiver : ASTNode
    end

    # Returns the method name that is being checked for.
    def name : StringLiteral
    end
  end

  # A `require` statement.
  class Require < ASTNode
    # Returns the argument of the `require`.
    def path : StringLiteral
    end
  end

  # A `when` inside a `case`.
  class When < ASTNode
    # Returns the conditions of this `when`.
    def conds : ArrayLiteral
    end

    # Returns the body of this `when`.
    def body : ASTNode
    end
  end

  # A `case` expression.
  class Case < ASTNode
    # Returns the condition (target) of this `case`.
    def cond : ASTNode
    end

    # Returns the `when`s of this `case`.
    def whens : ArrayLiteral(When)
    end

    # Returns the `else` of this `case`.
    def else : ArrayLiteral(When)
    end
  end

  # A `select` expression.
  # class Select < ASTNode
  # end

  # Node that represents an implicit object in:
  #
  #     case foo
  #     when .bar? # this is a call with an implicit object
  #     end
  class ImplicitObj < ASTNode
  end

  # A Path to a constant or type, like `Foo` or `Foo::Bar::Baz`.
  class Path < ASTNode
    # Returns an array with each separate part of this path.
    def names : ArrayLiteral(MacroId)
    end

    # Returns `true` if this is a global path (starts with `::`)
    def global? : BoolLiteral
    end

    # Resolves this path to a `TypeNode` if it denotes a type, to
    # the value of a constant if it denotes a constant, or otherwise
    # gives a compile-time error.
    def resolve : ASTNode
    end

    # Resolves this path to a `TypeNode` if it denotes a type, to
    # the value of a constant if it denotes a constant, or otherwise
    # returns a `NilLiteral`.
    def resolve? : ASTNode | NilLiteral
    end
  end

  # A class definition.
  class ClassDef < ASTNode
  end

  # A module definition.
  # class ModuleDef < ASTNode
  # end

  # A `while` expression
  class While < ASTNode
    # Returns this while's condition.
    def cond : ASTNode
    end

    # Returns this while's body.
    def body : ASTNode
    end
  end

  # class Until < ASTNode
  # end

  # A generic instantiation, like `Foo(T)` or `Foo::Bar::Baz(T)`
  class Generic < ASTNode
    # Returns the path to the generic.
    def name : Path
    end

    # Returns the arguments (the type variables) of this instantiation.
    def type_vars : ArrayLiteral(ASTNode)
    end

    # Returns the named arguments of this instantiation, if any.
    def named_args : NamedTupleLiteral | NilLiteral
    end
  end

  # A type declaration like `x : Int32`
  class TypeDeclaration < ASTNode
    # Returns the variable part of the declaration.
    def var : MacroId
    end

    # Returns the type part of the declaration.
    def type : ASTNode
    end

    # The value assigned to the variable, if any.
    def value : ASTNode | Nop
    end
  end

  # An uninitialized variable declaration: `a = uninitialized Int32`
  class UninitializedVar < ASTNode
    # Returns the variable part of the declaration.
    def var : MacroId
    end

    # Returns the type part of the declaration.
    def type : ASTNode
    end
  end

  # class Rescue < ASTNode
  # end

  # class ExceptionHandler < ASTNode
  # end

  # class ProcLiteral < ASTNode
  # end

  # class ProcPointer < ASTNode
  # end

  # A type union, like `(Int32 | String)`.
  class Union < ASTNode
    # Returns the types of this union.
    def types : ArrayLiteral(ASTNode)
    end
  end

  # class Self < ASTNode
  # end

  # abstract class ControlExpression < ASTNode
  # end

  # class Return < ControlExpression
  # end

  # class Break < ControlExpression
  # end

  # class Next < ControlExpression
  # end

  # class Yield < ASTNode
  # end

  # class Include < ASTNode
  # end

  # class Extend < ASTNode
  # end

  # class LibDef < ASTNode
  # end

  # class FunDef < ASTNode
  # end

  # class TypeDef < ASTNode
  # end

  # abstract class CStructOrUnionDef < ASTNode
  # end

  # class StructDef < CStructOrUnionDef
  # end

  # class UnionDef < CStructOrUnionDef
  # end

  # class EnumDef < ASTNode
  # end

  # class ExternalVar < ASTNode
  # end

  # class Alias < ASTNode
  # end

  # class Metaclass < ASTNode
  # end

  # A cast call: `obj.as(to)`
  class Cast < ASTNode
    # Returns the object part of the cast.
    def obj : ASTNode
    end

    # Returns the target type of the cast.
    def to : ASTNode
    end
  end

  # A cast call: `obj.as?(to)`
  class NilableCast < ASTNode
    # Returns the object part of the cast.
    def obj : ASTNode
    end

    # Returns the target type of the cast.
    def to : ASTNode
    end
  end

  # class TypeOf < ASTNode
  # end

  # class Attribute < ASTNode
  # end

  # A macro expression,
  # surrounded by {{ ... }} (output = true)
  # or by {% ... %} (output = false)
  # class MacroExpression < ASTNode
  # end

  # Free text that is part of a macro
  # class MacroLiteral < ASTNode
  # end

  # if inside a macro
  # class MacroIf < ASTNode
  # end

  # for inside a macro:
  # class MacroFor < ASTNode
  # end

  # class Underscore < ASTNode
  # end

  # A splat expression: `*exp`.
  class Splat < ASTNode
    # Returns the splatted expression.
    def exp : ASTNode
    end
  end

  # class MagicConstant < ASTNode
  # end

  # A fictitious node representing an idenfitifer like, `foo`, `Bar` or `something_else`.
  #
  # The parser doesn't create this nodes. Instead, you create them by invoking `id`
  # on some nodes. For example, invoking `id` on a `StringLiteral` returns a `MacroId`
  # for the string's content. Similarly, invoking ID on a `SymbolLiteral`, `Call`, `Var` and `Path`
  # return MacroIds for the node's content.
  #
  # This allows you to treat strings, symbols, variables and calls uniformly. For example:
  #
  # ```text
  # macro getter(name)
  #   def {{name.id}}
  #     @{{name.id}}
  #   end
  # end
  #
  # getter unicorns
  # getter :unicorns
  # getter "unicorns"
  # ```
  #
  # All of the above macro calls work because we invoked `id`, and the generated code
  # looks like this:
  #
  # ```
  # def unicorns
  #   @unicorns
  # end
  # ```
  #
  # If we hand't use `id`, the generated code would have been this:
  #
  # ```text
  # def unicorns
  #   @unicorns
  # end
  #
  # def :unicorns
  #   @:unicorns
  # end
  #
  # def "unicorns"
  #   @"unicorns"
  # end
  # ```
  #
  # The last two definitions are invalid and so will give a compile-time error.
  class MacroId < ASTNode
    # Returns self.
    def id : MacroId
    end

    # Similar to `String#[]`.
    def [](range : RangeLiteral) : MacroId
    end

    # Similar to `String#=~`.
    def =~(range : RegexLiteral) : BoolLiteral
    end

    # Similar to `String#+`.
    def +(other : StringLiteral | CharLiteral) : MacroId
    end

    # Similar to `String#capitalize`.
    def capitalize : MacroId
    end

    # Similar to `String#chars`.
    def chars : ArrayLiteral(CharLiteral)
    end

    # Similar to `String#chomp`.
    def chomp : MacroId
    end

    # Similar to `String#downcase`.
    def downcase : MacroId
    end

    # Similar to `String#empty?`.
    def empty? : BoolLiteral
    end

    # Similar to `String#ends_with?`.
    def ends_with?(other : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#gsub`.
    def gsub(regex : RegexLiteral, replacement : StringLiteral) : MacroId
    end

    # Similar to `String#includes?`.
    def includes?(search : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#size`.
    def size : NumberLiteral
    end

    # Similar to `String#lines`.
    def lines : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#split`.
    def split : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#split`.
    def split(node : ASTNode) : ArrayLiteral(StringLiteral)
    end

    # Similar to `String#starts_with?`.
    def starts_with?(other : StringLiteral | CharLiteral) : BoolLiteral
    end

    # Similar to `String#strip`.
    def strip : MacroId
    end

    # Similar to `String#tr`.
    def tr(from : StringLiteral, to : StringLiteral) : MacroId
    end

    # Similar to `String#upcase`.
    def upcase : MacroId
    end
  end

  # Represents a type in the program, like `Int32` or `String`.
  class TypeNode < ASTNode
    # Returns `true` if this type is abstract.
    def abstract? : BoolLiteral
    end

    # Returns `true` if this type is a union type, `false` otherwise.
    #
    # See also: `union_types`.
    def union? : BoolLiteral
    end

    # Returns the types comforming a union type, if this is a union type.
    # Gives a compile error otherwise.
    #
    # See also: `union?`.
    def union_types : ArrayLiteral(TypeNode)
    end

    # Returns the fully qualified name of this type.
    def name : MacroId
    end

    # Returns the type variables of the generic type. If the type is not
    # generic, an empty array is returned.
    def type_vars : ArrayLiteral(TypeNode)
    end

    # Returns the instance variables of this type.
    def instance_vars : ArrayLiteral(MetaVar)
    end

    # Returns all ancestors of this type.
    def ancestors : ArrayLiteral(TypeNode)
    end

    # Returns the direct superclass of this type.
    def superclass : TypeNode | NilLiteral
    end

    # Returns the direct subclasses of this type.
    def subclasses : ArrayLiteral(TypeNode)
    end

    # Returns all subclasses of this type.
    def all_subclasses : ArrayLiteral(TypeNode)
    end

    # Returns the constants and types defined by this type.
    def constants : ArrayLiteral(MacroId)
    end

    # Returns a constant defined in this type.
    #
    # If the constant is a constant (like `A = 1`), then its value
    # as an `ASTNode` is returned. If the constant is a type, the
    # type is returned as a `TypeNode`. Otherwise, `NilLiteral` is returned.
    def constant(name : StringLiteral | SymbolLiteral | MacroId) : ASTNode
    end

    # Returns `true` if this type has a constant. For example `DEFAULT_OPTIONS`
    # (the name you pass to this method is `"DEFAULT_OPTIONS"` or `:DEFAULT_OPTIONS`
    # in this cases).
    def has_constant?(name : StringLiteral | SymbolLiteral) : BoolLiteral
    end

    # Returns the instance methods defined by this type, without including
    # inherited methods.
    def methods : ArrayLiteral(Def)
    end

    # Returns `true` if this type has a method. For example `default_options`
    # (the name you pass to this method is `"default_options"` or `:default_options`
    # in this cases).
    def has_method?(name : StringLiteral | SymbolLiteral) : BoolLiteral
    end

    # Returns `true` if this type has an attribute. For example `@[Flags]`
    # or `@[Packed]` (the name you pass to this method is `"Flags"` or `"Packed"`
    # in these cases).
    def has_attribute?(name : StringLiteral | SymbolLiteral) : BoolLiteral
    end

    # Returns the number of elements in this tuple type or tuple metaclass type.
    # Gives a compile error if this is not one of those types.
    def size : NumberLiteral
    end

    # Returns the keys in this named tuple type.
    # Gives a compile error if this is not a named tuple type.
    def keys : ArrayLiteral(MacroId)
    end

    # Returns the type for the given key in this named tuple type.
    # Gives a compile error if this is not a named tuple type.
    def [](key : SymbolLiteral | MacroId) : TypeNode | NilLiteral
    end

    # Returns the class of this type. With this you can, for example, obtain class
    # methods by invoking `type.class.methods`.
    def class : TypeNode
    end

    # Returns the instance type of this type, if it's a class type,
    # or `self` otherwise. This is the opposite of `#class`.
    def instance : TypeNode
    end

    # Determines if `self` overrides any method named *method* from type *type*.
    #
    # ```
    # class Foo
    #   def one
    #     1
    #   end
    #
    #   def two
    #     2
    #   end
    # end
    #
    # class Bar < Foo
    #   def one
    #     11
    #   end
    # end
    #
    # {{ Bar.overrides?(Foo, "one") }} # => true
    # {{ Bar.overrides?(Foo, "two") }} # => false
    # ```
    def overrides?(type : TypeNode, method : StringLiteral | SymbolLiteral | MacroId) : Bool
    end

    # Returns `true` if *other* is an ancestor of `self`.
    def <(other : TypeNode) : BoolLiteral
    end

    # Returns `true` if `self` is the same as *other* or if
    # *other* is an ancestor of `self`.
    def <=(other : TypeNode) : BoolLiteral
    end

    # Returns `true` if `self` is an ancestor of *other*.
    def >(other : TypeNode) : BoolLiteral
    end

    # Returns `true` if *other* is the same as `self` or if
    # `self` is an ancestor of *other*.
    def >=(other : TypeNode) : BoolLiteral
    end
  end
end
