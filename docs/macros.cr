# The Macros module is a fictitious module used to document macros
# and macro methods.
#
# You can invoke a **fixed subset** of methods on AST nodes at compile-time. These methods
# are documented on the classes in this module. Additionally, methods of the
# `Macros` module are top-level methods that you can invoke, like `puts` and `run`.
module Macros
  # Outputs the current macro's buffer to the standard output. Useful for debugging
  # a macro to see what's being generated. Use it like `{{debug()}}`, the parenthesis
  # are mandatory.
  def debug : Nop
  end

  # Gets the value of an environment variable at compile-time, or `nil` if it doesn't exist.
  def env(name) : StringLiteral | NilLiteral
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

  # Gives a compile-time error with the given message.
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
  # # fetch.cr
  # require "http/client"
  #
  # puts HTTP::Client.get(ARGV[0]).body
  # ```
  #
  # ```
  # # main.cr
  # macro invoke_fetch
  #   {{ run("./fetch", "http://example.com").stringify }}
  # end
  #
  # puts invoke_fetch
  # ```
  #
  # The above generates a program that will have the contents of `http://example.com`.
  # A connection to `http://example.com` is never made at runtime.
  def run(filename, *args) : MacroId
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
    # Note that invoking stringify on a string literal will return a StringLiteral
    # that contains a string literal.
    #
    # ```
    # macro test
    #   {{ "foo".stringify }}
    # end
    #
    # puts test # prints "foo" (including the double quotes)
    def stringify : StringLiteral
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

    # Returns true if this node's textual representation is the same as
    # the other node.
    def ==(other : ASTNode) : BoolLiteral
    end

    # Returns true if this node's textual representation is not the same as
    # the other node.
    def !=(other : ASTNode) : BoolLiteral
    end

    # Returns true if this node is *falsey*, and false if it's *truthy*.
    def ! : BoolLiteral
    end

    # Tests if this node is of a specific type. For example:
    #
    # ```
    # macro test(node)
    #   {% if node.is_a?(NumberLiteral) %}
    #     puts "Got a number literal"
    #   {% else %}
    #     puts "Didn't get a number literal"
    #   {% end %}
    # end
    #
    # test 1    # => prints "Got a number literal"
    # test "hi" # => prints "Didn't get a number literal"
    # ```
    def is_a?(name) : BoolLiteral
    end

    # Gives a compile-time error with the given message. This will
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

    # Same as Number#+
    def +(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#-
    def -(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#*
    def *(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#/
    def /(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#%
    def %(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#&
    def &(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#|
    def |(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#^
    def ^(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#**
    def **(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#<<
    def <<(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#>>
    def >>(other : NumberLiteral) : NumberLiteral
    end

    # Same as Number#+
    def + : NumberLiteral
    end

    # Same as Number#-
    def - : NumberLiteral
    end

    # Same as Number#~
    def ~ : NumberLiteral
    end
  end

  # A char literal.
  class CharLiteral < ASTNode
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

  # class StringInterpolation < ASTNode
  # end

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
    def argify : MacroId
    end

    # Similar to `Array#empty?`
    def empty? : BoolLiteral
    end

    # Similar to `Enumerable#find`
    def find(&block) : ASTNode | NilLiteral
    end

    # Similar to `Array#first`, but returns a NilLiteral if the array is empty.
    def first : ASTNode | NilLiteral
    end

    # Similar to `Enumerable#includes?(obj)`.
    def includes?(node : ASTNode) : BoolLiteral
    end

    # Similar to `Enumerable#join`
    def join(separator) : StringLiteral
    end

    # Similar to `Array#last`, but returns a NilLiteral if the array is empty.
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

    # Similar to `Hash#[]`
    def [](key : ASTNode) : ASTNode
    end

    # Similar to `Hash#[]=`
    def []=(key : ASTNode) : ASTNode
    end
  end

  # A range literal.
  class RangeLiteral < ASTNode
  end

  # A regex literal.
  class RegexLiteral < ASTNode
  end

  # A tuple literal.
  class TupleLiteral < ASTNode
    # Similar to `Tuple#empty?`
    def empty? : BoolLiteral
    end

    # Similar to `Tuple#size`
    def size : NumberLiteral
    end

    # Similar to `Tuple#[]`
    def [](index : NumberLiteral) : ASTNode
    end
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
    # Returns this vars's name as a `MacroId`.
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
  end

  class Expressions < ASTNode
    # Returns the expressions' expressions
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

    # Returns this call's arguments.
    def args : ArrayLiteral
    end

    # Returns this call's receiver, if any.
    def receiver : ASTNode | Nop
    end

    # Returns this call's block, if any.
    def block : Block | Nop
    end

    # Returns this call's named arguments, if any.
    def named_args : ArrayLiteral(NamedArgument) | Nop
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
  # class If < ASTNode
  # end

  # class Unless < ASTNode
  # end

  # An ifdef expression.
  # class IfDef < ASTNode
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

  # Assign expression.
  # class MultiAssign < ASTNode
  # end

  # An instance variable.
  # class InstanceVar < ASTNode
  # end

  # class ReadInstanceVar < ASTNode
  # end

  # A class variable.
  # class ClassVar < ASTNode
  # end

  # A global variable.
  # class Global < ASTNode
  # end

  # abstract class BinaryOp < ASTNode
  # end

  # Expressions and.
  # class And < BinaryOp
  # end

  # Expressions or.
  # class Or < BinaryOp
  # end

  # A def argument.
  class Arg < ASTNode
    # Returns the name of this argument.
    def name : MacroId
    end

    # Returns the default value of this argument, if any.
    def default_value : ASTNode | Nop
    end

    # Returns the type restriction of this argument, if any.
    def restriction : ASTNode | Nop
    end
  end

  # class Fun < ASTNode
  # end

  # A method definition.
  class Def < ASTNode
    # Returns the name of this method.
    def name : MacroId
    end

    # Returns the body of this method.
    def body : ASTNode
    end

    # Returns the arguments of this method.
    def args : ArrayLiteral(Arg)
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
  # class Macro < ASTNode
  # end

  # abstract class UnaryExpression < ASTNode
  # end

  # class Not < UnaryExpression
  # end

  # class PointerOf < UnaryExpression
  # end

  # class SizeOf < UnaryExpression
  # end

  # class InstanceSizeOf < UnaryExpression
  # end

  # class Out < UnaryExpression
  # end

  # class VisibilityModifier < ASTNode
  # end

  # class IsA < ASTNode
  # end

  # class RespondsTo < ASTNode
  # end

  # class Require < ASTNode
  # end

  # A `when` inside a `case`
  class When < ASTNode
    # Returns the conditions of this `when`.
    def conds : ArrayLiteral
    end

    # Returns the body of this `when`.
    def body : ASTNode
    end
  end

  # A `case` expression
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

  # class ImplicitObj < ASTNode
  # end

  # A Path to a constant, like `Foo` or `Foo::Bar::Baz`.
  # class Path < ASTNode
  # end

  # A class definition.
  # class ClassDef < ASTNode
  # end

  # A module definition.
  # class ModuleDef < ASTNode
  # end

  # class While < ASTNode
  # end

  # class Until < ASTNode
  # end

  # A generic instantiation, like `Foo(T)` or `Foo::Bar::Baz(T)`
  # class Generic < ASTNode
  # end

  # A type declaration like `x : Int32`
  class TypeDeclaration < ASTNode
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

  # class FunLiteral < ASTNode
  # end

  # class FunPointer < ASTNode
  # end

  # class Union < ASTNode
  # end

  # class Virtual < ASTNode
  # end

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

  # abstract class StructOrUnionDef < ASTNode
  # end

  # class StructDef < StructOrUnionDef
  # end

  # class UnionDef < StructOrUnionDef
  # end

  # class EnumDef < ASTNode
  # end

  # class ExternalVar < ASTNode
  # end

  # class Alias < ASTNode
  # end

  # class Metaclass < ASTNode
  # end

  class Cast < ASTNode
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
  # on some nodes. For example, invoking `id` on a `StringLiteral` returns a MacroId
  # for the string's content. Similarly, invoking ID on a `SymbolLiteral`, `Call`, `Var` and `Path`
  # return MacroIds for the node's content.
  #
  # This allows you to treat strings, symbols, variables and calls unifomly. For example:
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
    # Returns true if this type is abstract.
    def abstract? : BoolLiteral
    end

    # Returns the fully qualified name of this type.
    def name : MacroId
    end

    # Returns the instance variables of this type.
    def instance_vars : ArrayLiteral(MetaVar)
    end

    # Returns the direct superclass of this type.
    def superclass : TypeNode | NilLiteral
    end

    # Returns the direct subclasses of this type.
    def subclasses : ArrayLiteral(TypeNode)
    end

    # Returns all subclasses of this type.
    def subclasses : ArrayLiteral(TypeNode)
    end

    # Returns the constants and types defined by this type.
    def subclasses : ArrayLiteral(MacroId)
    end

    # Returns the instance methods defined by this type, without including
    # inherited methods.
    def methods : Array(Def)
    end

    # Returns true if this type has an attribute. For example `@[Flags]`
    # or `@[Packed]` (the name you pass to this method is "Flags" or "Packed"
    # in these cases).
    def has_attribute?(name : StringLiteral | SymbolLiteral) : BoolLiteral
    end

    # Returns true if this type has a constant. For example `DEFAULT_OPTIONS`
    # (the name you pass to this method is "DEFAULT_OPTIONS" or :DEFAULT_OPTIONS
    # in this cases).
    def has_constant?(name : StringLiteral | SymbolLiteral) : BoolLiteral
    end

    # Returns the number of elements in this tuple type or tuple metaclass type.
    # Gives a compile error if this is not one of those types.
    def size : NumberLiteral
    end

    # Returns true if this type is a union type, false otherwise.
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

    # Returns the type variables of the generic type. If the type is not
    # generic, an empty array is returned.
    def type_vars : ArrayLiteral(TypeNode)
    end

    # Returns the class of this type. With this you can, for example, obtain class
    # methods by invoking `type.class.methods`.
    def class : TypeNode
    end
  end

  # A binary expression like `And` and `Or`.
  class BinaryOp < ASTNode
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
end
