module Crystal
  # Base class for nodes in the grammar.
  abstract class ASTNode
    property location : Location?
    property end_location : Location?

    def at(@location : Location?)
      self
    end

    def at(node : ASTNode)
      @location = node.location
      @end_location = node.end_location
      self
    end

    def at_end(node : ASTNode)
      @end_location = node.end_location
      self
    end

    def at_end(@end_location : Location?)
      self
    end

    def clone
      clone = clone_without_location
      clone.location = location
      clone.end_location = end_location
      clone.attributes = attributes
      clone
    end

    def attributes
    end

    def attributes=(attributes)
    end

    def doc
    end

    def doc=(doc)
    end

    def has_attribute?(name)
      Attribute.any?(attributes, name)
    end

    def name_column_number
      @location.try(&.column_number) || 0
    end

    def name_size
      0
    end

    def visibility=(visibility : Visibility)
    end

    def visibility
      Visibility::Public
    end

    def nop?
      false
    end

    def true_literal?
      false
    end

    def false_literal?
      false
    end

    macro def class_desc : String
      {{@type.name.split("::").last.id.stringify}}
    end
  end

  class Nop < ASTNode
    def nop?
      true
    end

    def clone_without_location
      Nop.new
    end

    def_equals_and_hash
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    property expressions : Array(ASTNode)
    property keyword : Symbol?

    def self.from(obj : Nil)
      Nop.new
    end

    def self.from(obj : Array)
      case obj.size
      when 0
        Nop.new
      when 1
        obj.first
      else
        new obj
      end
    end

    def self.from(obj : ASTNode)
      obj
    end

    def initialize(@expressions = [] of ASTNode)
    end

    def empty?
      @expressions.empty?
    end

    def [](i)
      @expressions[i]
    end

    def last
      @expressions.last
    end

    def end_location
      @end_location || @expressions.last?.try &.end_location
    end

    def accept_children(visitor)
      @expressions.each &.accept visitor
    end

    def clone_without_location
      Expressions.new(@expressions.clone)
    end

    def_equals_and_hash expressions
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def clone_without_location
      NilLiteral.new
    end

    def_equals_and_hash
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    property value : Bool

    def initialize(@value)
    end

    def false_literal?
      !value
    end

    def true_literal?
      value
    end

    def clone_without_location
      BoolLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  # Any number literal.
  # kind stores a symbol indicating which type is it: i32, u16, f32, f64, etc.
  class NumberLiteral < ASTNode
    property value : String
    property kind : Symbol

    def initialize(@value : String, @kind = :i32)
    end

    def initialize(value : Number, @kind = :i32)
      @value = value.to_s
    end

    def has_sign?
      @value[0] == '+' || @value[0] == '-'
    end

    def clone_without_location
      NumberLiteral.new(@value, @kind)
    end

    def_equals value.to_f64, kind
    def_hash value, kind
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    property value : Char

    def initialize(@value : Char)
    end

    def clone_without_location
      CharLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  class StringLiteral < ASTNode
    property value : String

    def initialize(@value : String)
    end

    def clone_without_location
      StringLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  class StringInterpolation < ASTNode
    property expressions : Array(ASTNode)

    def initialize(@expressions : Array(ASTNode))
    end

    def accept_children(visitor)
      @expressions.each &.accept visitor
    end

    def clone_without_location
      StringInterpolation.new(@expressions.clone)
    end

    def_equals_and_hash expressions
  end

  class SymbolLiteral < ASTNode
    property value : String

    def initialize(@value : String)
    end

    def clone_without_location
      SymbolLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  # An array literal.
  #
  #  '[' [ expression [ ',' expression ]* ] ']'
  #
  class ArrayLiteral < ASTNode
    property elements : Array(ASTNode)
    property of : ASTNode?
    property name : ASTNode?

    def initialize(@elements = [] of ASTNode, @of = nil, @name = nil)
    end

    def self.map(values)
      new(values.map { |value| (yield value) as ASTNode })
    end

    def accept_children(visitor)
      @name.try &.accept visitor
      elements.each &.accept visitor
      @of.try &.accept visitor
    end

    def clone_without_location
      ArrayLiteral.new(@elements.clone, @of.clone, @name.clone)
    end

    def_equals_and_hash @elements, @of, @name
  end

  class HashLiteral < ASTNode
    property entries : Array(Entry)
    property of : Entry?
    property name : ASTNode?

    def initialize(@entries = [] of Entry, @of = nil, @name = nil)
    end

    def accept_children(visitor)
      @name.try &.accept visitor
      @entries.each do |entry|
        entry.key.accept visitor
        entry.value.accept visitor
      end
      if of = @of
        of.key.accept visitor
        of.value.accept visitor
      end
    end

    def clone_without_location
      HashLiteral.new(@entries.clone, @of.clone, @name.clone)
    end

    def_equals_and_hash @entries, @of, @name

    record Entry, key : ASTNode, value : ASTNode
  end

  class RangeLiteral < ASTNode
    property from : ASTNode
    property to : ASTNode
    property exclusive : Bool

    def initialize(@from, @to, @exclusive)
    end

    def accept_children(visitor)
      @from.accept visitor
      @to.accept visitor
    end

    def clone_without_location
      RangeLiteral.new(@from.clone, @to.clone, @exclusive.clone)
    end

    def_equals_and_hash @from, @to, @exclusive
  end

  class RegexLiteral < ASTNode
    property value : ASTNode
    property options : Regex::Options

    def initialize(@value, @options = Regex::Options::None)
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def clone_without_location
      RegexLiteral.new(@value.clone, @options)
    end

    def_equals_and_hash @value, @options
  end

  class TupleLiteral < ASTNode
    property elements : Array(ASTNode)

    def initialize(@elements)
    end

    def accept_children(visitor)
      elements.each &.accept visitor
    end

    def clone_without_location
      TupleLiteral.new(elements.clone)
    end

    def_equals_and_hash elements
  end

  module SpecialVar
    def special_var?
      @name.starts_with? '$'
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    include SpecialVar

    property name : String

    def initialize(@name : String)
    end

    def name_size
      name.size
    end

    def clone_without_location
      Var.new(@name)
    end

    def_equals name
    def_hash name
  end

  # A code block.
  #
  #     'do' [ '|' arg [ ',' arg ]* '|' ]
  #       body
  #     'end'
  #   |
  #     '{' [ '|' arg [ ',' arg ]* '|' ] body '}'
  #
  class Block < ASTNode
    property args : Array(Var)
    property body : ASTNode
    property call : Call?

    def initialize(@args = [] of Var, body = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      Block.new(@args.clone, @body.clone)
    end

    def_equals_and_hash args, body
  end

  # A method call.
  #
  #     [ obj '.' ] name '(' ')' [ block ]
  #   |
  #     [ obj '.' ] name '(' arg [ ',' arg ]* ')' [ block ]
  #   |
  #     [ obj '.' ] name arg [ ',' arg ]* [ block ]
  #   |
  #     arg name arg
  #
  # The last syntax is for infix operators, and name will be
  # the symbol of that operator instead of a string.
  #
  class Call < ASTNode
    property obj : ASTNode?
    property name : String
    property args : Array(ASTNode)
    property block : Block?
    property block_arg : ASTNode?
    property named_args : Array(NamedArgument)?
    property global : Bool
    property name_column_number : Int32
    property has_parenthesis : Bool
    property name_size : Int32
    property doc : String?
    property? is_expansion : Bool
    property visibility : Visibility

    def initialize(@obj, @name, @args = [] of ASTNode, @block = nil, @block_arg = nil, @named_args = nil, global = false, @name_column_number = 0, has_parenthesis = false)
      @name_size = -1
      @global = !!global
      @has_parenthesis = !!has_parenthesis
      @is_expansion = false
      @visibility = Visibility::Public
      if block = @block
        block.call = self
      end
    end

    def self.new(obj, name, arg : ASTNode)
      new obj, name, [arg] of ASTNode
    end

    def self.new(obj, name, arg1 : ASTNode, arg2 : ASTNode)
      new obj, name, [arg1, arg2] of ASTNode
    end

    def self.global(name, arg : ASTNode)
      new nil, name, [arg] of ASTNode, global: true
    end

    def self.global(name, arg1 : ASTNode, arg2 : ASTNode)
      new nil, name, [arg1, arg2] of ASTNode, global: true
    end

    def name_size
      if @name_size == -1
        @name_size = name.to_s.ends_with?('=') || name.to_s.ends_with?('@') ? name.size - 1 : name.size
      end
      @name_size
    end

    def accept_children(visitor)
      @obj.try &.accept visitor
      @args.each &.accept visitor
      @named_args.try &.each &.accept visitor
      @block_arg.try &.accept visitor
      @block.try &.accept visitor
    end

    def clone_without_location
      clone = Call.new(@obj.clone, @name, @args.clone, @block.clone, @block_arg.clone, @named_args.clone, @global, @name_column_number, @has_parenthesis)
      clone.name_size = name_size
      clone.is_expansion = is_expansion?
      clone
    end

    def name_location
      loc = location.not_nil!
      Location.new(loc.line_number, name_column_number, loc.filename)
    end

    def name_end_location
      loc = location.not_nil!
      Location.new(loc.line_number, name_column_number + name_size, loc.filename)
    end

    def_equals_and_hash obj, name, args, block, block_arg, named_args, global
  end

  class NamedArgument < ASTNode
    property name : String
    property value : ASTNode

    def initialize(@name : String, @value : ASTNode)
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def clone_without_location
      NamedArgument.new(name, value.clone)
    end

    def_equals_and_hash name, value
  end

  # An if expression.
  #
  #     'if' cond
  #       then
  #     [
  #     'else'
  #       else
  #     ]
  #     'end'
  #
  # An if elsif end is parsed as an If whose
  # else is another If.
  class If < ASTNode
    property cond : ASTNode
    property then : ASTNode
    property else : ASTNode
    property binary : Symbol?

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      a_if = If.new(@cond.clone, @then.clone, @else.clone)
      a_if.binary = binary
      a_if
    end

    def_equals_and_hash @cond, @then, @else
  end

  class Unless < ASTNode
    property cond : ASTNode
    property then : ASTNode
    property else : ASTNode

    def initialize(@cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      Unless.new(@cond.clone, @then.clone, @else.clone)
    end

    def_equals_and_hash @cond, @then, @else
  end

  # An ifdef expression.
  #
  #     'ifdef' cond
  #       then
  #     [
  #     'else'
  #       else
  #     ]
  #     'end'
  #
  # An if elsif end is parsed as an If whose
  # else is another If.
  class IfDef < ASTNode
    property cond : ASTNode
    property then : ASTNode
    property else : ASTNode

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      IfDef.new(@cond.clone, @then.clone, @else.clone)
    end

    def_equals_and_hash @cond, @then, @else
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < ASTNode
    property target : ASTNode
    property value : ASTNode
    property doc : String?

    def initialize(@target, @value)
    end

    def accept_children(visitor)
      @target.accept visitor
      @value.accept visitor
    end

    def end_location
      @end_location || value.end_location
    end

    def clone_without_location
      Assign.new(@target.clone, @value.clone)
    end

    def_equals_and_hash @target, @value
  end

  # Assign expression.
  #
  #     target [',' target]+ '=' value [',' value]*
  #
  class MultiAssign < ASTNode
    property targets : Array(ASTNode)
    property values : Array(ASTNode)

    def initialize(@targets, @values)
    end

    def accept_children(visitor)
      @targets.each &.accept visitor
      @values.each &.accept visitor
    end

    def end_location
      @end_location || @values.last.end_location
    end

    def ==(other : self)
      other.targets == targets && other.values == values
    end

    def clone_without_location
      MultiAssign.new(@targets.clone, @values.clone)
    end

    def_hash @targets, @values
  end

  # An instance variable.
  class InstanceVar < ASTNode
    property name : String

    def initialize(@name)
    end

    def name_size
      name.size
    end

    def clone_without_location
      InstanceVar.new(@name)
    end

    def_equals_and_hash name
  end

  class ReadInstanceVar < ASTNode
    property obj : ASTNode
    property name : String

    def initialize(@obj, @name)
    end

    def accept_children(visitor)
      @obj.accept visitor
    end

    def clone_without_location
      ReadInstanceVar.new(@obj.clone, @name)
    end

    def_equals_and_hash @obj, @name
  end

  class ClassVar < ASTNode
    property name : String

    def initialize(@name)
    end

    def clone_without_location
      ClassVar.new(@name)
    end

    def_equals_and_hash name
  end

  # A global variable.
  class Global < ASTNode
    property name : String

    def initialize(@name)
    end

    def name_size
      name.size
    end

    def clone_without_location
      Global.new(@name)
    end

    def_equals_and_hash name
  end

  abstract class BinaryOp < ASTNode
    property left : ASTNode
    property right : ASTNode

    def initialize(@left, @right)
    end

    def accept_children(visitor)
      @left.accept visitor
      @right.accept visitor
    end

    def end_location
      @end_location || @right.end_location
    end

    def_equals_and_hash left, right
  end

  # Expressions and.
  #
  #     expression '&&' expression
  #
  class And < BinaryOp
    def clone_without_location
      And.new(@left.clone, @right.clone)
    end
  end

  # Expressions or.
  #
  #     expression '||' expression
  #
  class Or < BinaryOp
    def clone_without_location
      Or.new(@left.clone, @right.clone)
    end
  end

  # A def argument.
  class Arg < ASTNode
    include SpecialVar

    property name : String
    property default_value : ASTNode?
    property restriction : ASTNode?
    property doc : String?

    def initialize(@name, @default_value : ASTNode? = nil, @restriction : ASTNode? = nil)
    end

    def accept_children(visitor)
      @default_value.try &.accept visitor
      @restriction.try &.accept visitor
    end

    def name_size
      name.size
    end

    def clone_without_location
      Arg.new @name, @default_value.clone, @restriction.clone
    end

    def_equals_and_hash name, default_value, restriction
  end

  class Fun < ASTNode
    property inputs : Array(ASTNode)?
    property output : ASTNode?

    def initialize(@inputs = nil, @output = nil)
    end

    def accept_children(visitor)
      @inputs.try &.each &.accept visitor
      @output.try &.accept visitor
    end

    def clone_without_location
      Fun.new(@inputs.clone, @output.clone)
    end

    def_equals_and_hash inputs, output
  end

  # A method definition.
  #
  #     'def' [ receiver '.' ] name
  #       body
  #     'end'
  #   |
  #     'def' [ receiver '.' ] name '(' [ arg [ ',' arg ]* ] ')'
  #       body
  #     'end'
  #   |
  #     'def' [ receiver '.' ] name arg [ ',' arg ]*
  #       body
  #     'end'
  #
  class Def < ASTNode
    property receiver : ASTNode?
    property name : String
    property args : Array(Arg)
    property body : ASTNode
    property block_arg : Arg?
    property? macro_def : Bool
    property return_type : ASTNode?
    property yields : Int32?
    property calls_super : Bool
    property calls_initialize : Bool
    property calls_previous_def : Bool
    property uses_block_arg : Bool
    property assigns_special_var : Bool
    property name_column_number : Int32
    property? abstract : Bool
    property attributes : Array(Attribute)?
    property splat_index : Int32?
    property doc : String?
    property visibility : Visibility

    def initialize(@name, @args = [] of Arg, body = nil, @receiver = nil, @block_arg = nil, @return_type = nil, @macro_def = false, @yields = nil, @abstract = false, @splat_index = nil)
      @body = Expressions.from body
      @calls_super = false
      @calls_initialize = false
      @calls_previous_def = false
      @uses_block_arg = false
      @assigns_special_var = false
      @raises = false
      @name_column_number = 0
      @visibility = Visibility::Public
    end

    def accept_children(visitor)
      @receiver.try &.accept visitor
      @args.each &.accept visitor
      @block_arg.try &.accept visitor
      @return_type.try &.accept visitor
      @body.accept visitor
    end

    def name_size
      name.size
    end

    def min_max_args_sizes
      max_size = args.size
      default_value_index = args.index(&.default_value)
      min_size = default_value_index || max_size
      if splat_index
        min_size -= 1 unless default_value_index
        max_size = Int32::MAX
      end
      {min_size, max_size}
    end

    def has_default_arguments?
      args.size > 0 && args.last.default_value
    end

    def clone_without_location
      a_def = Def.new(@name, @args.clone, @body.clone, @receiver.clone, @block_arg.clone, @return_type.clone, @macro_def, @yields, @abstract, @splat_index)
      a_def.calls_super = calls_super
      a_def.calls_initialize = calls_initialize
      a_def.calls_previous_def = calls_previous_def
      a_def.uses_block_arg = uses_block_arg
      a_def.assigns_special_var = assigns_special_var
      a_def.name_column_number = name_column_number
      a_def
    end

    def_equals_and_hash @name, @args, @body, @receiver, @block_arg, @return_type, @macro_def, @yields, @abstract, @splat_index
  end

  class Macro < ASTNode
    property name : String
    property args : Array(Arg)
    property body : ASTNode
    property block_arg : Arg?
    property name_column_number : Int32
    property splat_index : Int32?
    property doc : String?
    property visibility : Visibility

    def initialize(@name, @args = [] of Arg, @body = Nop.new, @block_arg = nil, @splat_index = nil)
      @name_column_number = 0
      @visibility = Visibility::Public
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @body.accept visitor
      @block_arg.try &.accept visitor
    end

    def name_size
      name.size
    end

    def matches?(call_args, named_args)
      call_args_size = call_args.size
      my_args_size = args.size
      min_args_size = args.index(&.default_value) || my_args_size
      max_args_size = my_args_size
      splat_index = self.splat_index
      if splat_index
        min_args_size -= 1
        max_args_size = Int32::MAX
      end

      # If there's a splat in the macros and named args in the call,
      # there's no match (it's confusing to determine what should happen)
      if named_args && splat_index
        return nil
      end

      # If there are more positional arguments than those required, there's no match
      # (if there's less they might be matched with named arguments)
      if call_args_size > max_args_size
        return false
      end

      # If there are named args we must check that all mandatory args
      # are covered by positional arguments or named arguments.
      if named_args
        mandatory_args = BitArray.new(my_args_size)
      elsif call_args_size < min_args_size
        # Otherwise, they must be matched by positional arguments
        return false
      end

      self.match(call_args) do |my_arg, my_arg_index, call_arg, call_arg_index|
        mandatory_args[my_arg_index] = true if mandatory_args
      end

      # Check named args
      named_args.try &.each do |named_arg|
        found_index = args.index { |arg| arg.name == named_arg.name }
        if found_index
          # A named arg can't target the splat index
          if found_index == splat_index
            return nil
          end

          # Check whether the named arg refers to an argument that was already specified
          if mandatory_args
            if mandatory_args[found_index]
              return false
            end

            mandatory_args[found_index] = true
          else
            if found_index < call_args_size
              return false
            end
          end
        else
          return false
        end
      end

      # Check that all mandatory args were specified
      # (either with positional arguments or with named arguments)
      if mandatory_args
        self.args.each_with_index do |arg, index|
          if index != splat_index && !arg.default_value && !mandatory_args[index]
            return nil
          end
        end
      end

      true
    end

    def clone_without_location
      Macro.new(@name, @args.clone, @body.clone, @block_arg.clone, @splat_index)
    end

    def_equals_and_hash @name, @args, @body, @block_arg, @splat_index
  end

  abstract class UnaryExpression < ASTNode
    property exp : ASTNode

    def initialize(@exp)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def_equals_and_hash exp
  end

  # Used only for flags
  class Not < UnaryExpression
    def clone_without_location
      Not.new(@exp.clone)
    end
  end

  class PointerOf < UnaryExpression
    def clone_without_location
      PointerOf.new(@exp.clone)
    end
  end

  class SizeOf < UnaryExpression
    def clone_without_location
      SizeOf.new(@exp.clone)
    end
  end

  class InstanceSizeOf < UnaryExpression
    def clone_without_location
      InstanceSizeOf.new(@exp.clone)
    end
  end

  class Out < UnaryExpression
    def clone_without_location
      Out.new(@exp.clone)
    end
  end

  class VisibilityModifier < ASTNode
    property modifier : Visibility
    property exp : ASTNode
    property doc : String?

    def initialize(@modifier : Visibility, @exp)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def clone_without_location
      VisibilityModifier.new(@modifier, @exp.clone)
    end

    def_equals_and_hash modifier, exp
  end

  class IsA < ASTNode
    property obj : ASTNode
    property const : ASTNode
    property? nil_check : Bool

    def initialize(@obj, @const, @nil_check = false)
    end

    def accept_children(visitor)
      @obj.accept visitor
      @const.accept visitor
    end

    def clone_without_location
      IsA.new(@obj.clone, @const.clone, @nil_check)
    end

    def_equals_and_hash @obj, @const, @nil_check
  end

  class RespondsTo < ASTNode
    property obj : ASTNode
    property name : String

    def initialize(@obj, @name)
    end

    def accept_children(visitor)
      obj.accept visitor
    end

    def clone_without_location
      RespondsTo.new(@obj.clone, @name)
    end

    def_equals_and_hash @obj, @name
  end

  class Require < ASTNode
    property string : String

    def initialize(@string)
    end

    def clone_without_location
      Require.new(@string)
    end

    def_equals_and_hash string
  end

  class When < ASTNode
    property conds : Array(ASTNode)
    property body : ASTNode

    def initialize(@conds, body = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @conds.each &.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      When.new(@conds.clone, @body.clone)
    end

    def_equals_and_hash @conds, @body
  end

  class Case < ASTNode
    property cond : ASTNode?
    property whens : Array(When)
    property else : ASTNode?

    def initialize(@cond, @whens, @else = nil)
    end

    def accept_children(visitor)
      @whens.each &.accept visitor
      @else.try &.accept visitor
    end

    def clone_without_location
      Case.new(@cond.clone, @whens.clone, @else.clone)
    end

    def_equals_and_hash @cond, @whens, @else
  end

  # Node that represents an implicit obj in:
  #
  #     case foo
  #     when .bar? # this is a call with an implicit obj
  #     end
  class ImplicitObj < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      self
    end

    def hash
      0
    end
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Path < ASTNode
    property names : Array(String)
    property global : Bool
    property name_size : Int32

    def initialize(@names : Array, @global = false)
      @name_size = 0
    end

    def self.new(name : String, global = false)
      new [name], global
    end

    def self.global(names)
      new names, true
    end

    # Returns true if this path has a single component
    # with the given name
    def single?(name)
      names.size == 1 && names.first == name
    end

    def clone_without_location
      ident = Path.new(@names.clone, @global)
      ident.name_size = name_size
      ident
    end

    def_equals_and_hash @names, @global
  end

  # Class definition:
  #
  #     'class' name [ '<' superclass ]
  #       body
  #     'end'
  #
  class ClassDef < ASTNode
    property name : Path
    property body : ASTNode
    property superclass : ASTNode?
    property type_vars : Array(String)?
    property? abstract : Bool
    property? struct : Bool
    property name_column_number : Int32
    property attributes : Array(Attribute)?
    property doc : String?

    def initialize(@name, body = nil, @superclass = nil, @type_vars = nil, @abstract = false, @struct = false, @name_column_number = 0)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @superclass.try &.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      ClassDef.new(@name, @body.clone, @superclass.clone, @type_vars.clone, @abstract, @struct, @name_column_number)
    end

    def_equals_and_hash @name, @body, @superclass, @type_vars, @abstract, @struct
  end

  # Module definition:
  #
  #     'module' name
  #       body
  #     'end'
  #
  class ModuleDef < ASTNode
    property name : Path
    property body : ASTNode
    property type_vars : Array(String)?
    property name_column_number : Int32
    property doc : String?

    def initialize(@name, body = nil, @type_vars = nil, @name_column_number = 0)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def clone_without_location
      ModuleDef.new(@name, @body.clone, @type_vars.clone, @name_column_number)
    end

    def_equals_and_hash @name, @body, @type_vars
  end

  # While expression.
  #
  #     'while' cond
  #       body
  #     'end'
  #
  class While < ASTNode
    property cond : ASTNode
    property body : ASTNode

    def initialize(@cond, body = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @cond.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      While.new(@cond.clone, @body.clone)
    end

    def_equals_and_hash @cond, @body
  end

  # Until expression.
  #
  #     'until' cond
  #       body
  #     'end'
  #
  class Until < ASTNode
    property cond : ASTNode
    property body : ASTNode

    def initialize(@cond, body = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @cond.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      Until.new(@cond.clone, @body.clone)
    end

    def_equals_and_hash @cond, @body
  end

  class Generic < ASTNode
    property name : Path
    property type_vars : Array(ASTNode)

    def initialize(@name, @type_vars : Array)
    end

    def self.new(name, type_var : ASTNode)
      new name, [type_var] of ASTNode
    end

    def accept_children(visitor)
      @name.accept visitor
      @type_vars.each &.accept visitor
    end

    def clone_without_location
      Generic.new(@name.clone, @type_vars.clone)
    end

    def_equals_and_hash @name, @type_vars
  end

  class TypeDeclaration < ASTNode
    property var : ASTNode
    property declared_type : ASTNode
    property value : ASTNode?

    def initialize(@var, @declared_type, @value = nil)
    end

    def accept_children(visitor)
      var.accept visitor
      declared_type.accept visitor
      value.try &.accept visitor
    end

    def name_size
      var = @var
      case var
      when Var
        var.name.size
      when InstanceVar
        var.name.size
      when ClassVar
        var.name.size
      when Global
        var.name.size
      else
        raise "can't happen"
      end
    end

    def clone_without_location
      TypeDeclaration.new(@var.clone, @declared_type.clone, @value.clone)
    end

    def_equals_and_hash @var, @declared_type, @value
  end

  class UninitializedVar < ASTNode
    property var : ASTNode
    property declared_type : ASTNode

    def initialize(@var, @declared_type)
    end

    def accept_children(visitor)
      var.accept visitor
      declared_type.accept visitor
    end

    def name_size
      var = @var
      case var
      when Var
        var.name.size
      when InstanceVar
        var.name.size
      else
        raise "can't happen"
      end
    end

    def clone_without_location
      UninitializedVar.new(@var.clone, @declared_type.clone)
    end

    def_equals_and_hash @var, @declared_type
  end

  class Rescue < ASTNode
    property body : ASTNode
    property types : Array(ASTNode)?
    property name : String?

    def initialize(body = nil, @types = nil, @name = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
      @types.try &.each &.accept visitor
    end

    def clone_without_location
      Rescue.new(@body.clone, @types.clone, @name)
    end

    def_equals_and_hash @body, @types, @name
  end

  class ExceptionHandler < ASTNode
    property body : ASTNode
    property rescues : Array(Rescue)?
    property else : ASTNode?
    property ensure : ASTNode?
    property implicit : Bool
    property suffix : Bool

    def initialize(body = nil, @rescues = nil, @else = nil, @ensure = nil)
      @body = Expressions.from body
      @implicit = false
      @suffix = false
    end

    def accept_children(visitor)
      @body.accept visitor
      @rescues.try &.each &.accept visitor
      @else.try &.accept visitor
      @ensure.try &.accept visitor
    end

    def clone_without_location
      ex = ExceptionHandler.new(@body.clone, @rescues.clone, @else.clone, @ensure.clone)
      ex.implicit = implicit
      ex.suffix = suffix
      ex
    end

    def_equals_and_hash @body, @rescues, @else, @ensure
  end

  class FunLiteral < ASTNode
    property def : Def

    def initialize(@def = Def.new("->"))
    end

    def accept_children(visitor)
      @def.accept visitor
    end

    def clone_without_location
      FunLiteral.new(@def.clone)
    end

    def_equals_and_hash @def
  end

  class FunPointer < ASTNode
    property obj : ASTNode?
    property name : String
    property args : Array(ASTNode)

    def initialize(@obj, @name, @args = [] of ASTNode)
    end

    def accept_children(visitor)
      @obj.try &.accept visitor
      @args.each &.accept visitor
    end

    def clone_without_location
      FunPointer.new(@obj.clone, @name, @args.clone)
    end

    def_equals_and_hash @obj, @name, @args
  end

  class Union < ASTNode
    property types : Array(ASTNode)

    def initialize(@types)
    end

    def accept_children(visitor)
      @types.each &.accept visitor
    end

    def clone_without_location
      Union.new(@types.clone)
    end

    def_equals_and_hash types
  end

  class Self < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      Self.new
    end

    def hash
      0
    end
  end

  abstract class ControlExpression < ASTNode
    property exp : ASTNode?

    def initialize(@exp : ASTNode? = nil)
    end

    def accept_children(visitor)
      @exp.try &.accept visitor
    end

    def end_location
      @end_location || @exp.try(&.end_location)
    end

    def_equals_and_hash exp
  end

  class Return < ControlExpression
    def clone_without_location
      Return.new(@exp.clone)
    end
  end

  class Break < ControlExpression
    def clone_without_location
      Break.new(@exp.clone)
    end
  end

  class Next < ControlExpression
    def clone_without_location
      Next.new(@exp.clone)
    end
  end

  class Yield < ASTNode
    property exps : Array(ASTNode)
    property scope : ASTNode?

    def initialize(@exps = [] of ASTNode, @scope = nil)
    end

    def accept_children(visitor)
      @scope.try &.accept visitor
      @exps.each &.accept visitor
    end

    def clone_without_location
      Yield.new(@exps.clone, @scope.clone)
    end

    def end_location
      @end_location || @exps.last?.try(&.end_location)
    end

    def_equals_and_hash @exps, @scope
  end

  class Include < ASTNode
    property name : ASTNode

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Include.new(@name)
    end

    def end_location
      @end_location || @name.end_location
    end

    def_equals_and_hash name
  end

  class Extend < ASTNode
    property name : ASTNode

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Extend.new(@name)
    end

    def end_location
      @end_location || @name.end_location
    end

    def_equals_and_hash name
  end

  class LibDef < ASTNode
    property name : String
    property body : ASTNode
    property name_column_number : Int32

    def initialize(@name, body = nil, @name_column_number = 0)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def clone_without_location
      LibDef.new(@name, @body.clone, @name_column_number)
    end

    def_equals_and_hash @name, @body
  end

  class FunDef < ASTNode
    property name : String
    property args : Array(Arg)
    property return_type : ASTNode?
    property varargs : Bool
    property body : ASTNode?
    property real_name : String
    property attributes : Array(Attribute)?
    property doc : String?

    def initialize(@name, @args = [] of Arg, @return_type = nil, @varargs = false, @body = nil, @real_name = name)
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @return_type.try &.accept visitor
      @body.try &.accept visitor
    end

    def clone_without_location
      FunDef.new(@name, @args.clone, @return_type.clone, @varargs, @body.clone, @real_name)
    end

    def_equals_and_hash @name, @args, @return_type, @varargs, @body, @real_name
  end

  class TypeDef < ASTNode
    property name : String
    property type_spec : ASTNode
    property name_column_number : Int32

    def initialize(@name, @type_spec, @name_column_number = 0)
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def clone_without_location
      TypeDef.new(@name, @type_spec.clone, @name_column_number)
    end

    def_equals_and_hash @name, @type_spec
  end

  abstract class StructOrUnionDef < ASTNode
    property name : String
    property body : ASTNode

    def initialize(@name, body = nil)
      @body = Expressions.from(body)
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def_equals_and_hash @name, @body
  end

  class StructDef < StructOrUnionDef
    property attributes : Array(Attribute)?

    def clone_without_location
      StructDef.new(@name, @body.clone)
    end
  end

  class UnionDef < StructOrUnionDef
    def clone_without_location
      UnionDef.new(@name, @body.clone)
    end
  end

  class EnumDef < ASTNode
    property name : Path
    property members : Array(ASTNode)
    property base_type : ASTNode?
    property attributes : Array(Attribute)?
    property doc : String?

    def initialize(@name, @members = [] of ASTNode, @base_type = nil)
    end

    def accept_children(visitor)
      @members.each &.accept visitor
      @base_type.try &.accept visitor
    end

    def clone_without_location
      EnumDef.new(@name, @members.clone, @base_type.clone)
    end

    def_equals_and_hash @name, @members, @base_type
  end

  class ExternalVar < ASTNode
    property name : String
    property type_spec : ASTNode
    property real_name : String?
    property attributes : Array(Attribute)?

    def initialize(@name, @type_spec, @real_name = nil)
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def clone_without_location
      ExternalVar.new(@name, @type_spec.clone, @real_name)
    end

    def_equals_and_hash @name, @type_spec, @real_name
  end

  class External < Def
    property real_name : String
    property varargs : Bool
    property! fun_def : FunDef

    def initialize(name : String, args : Array(Arg), body, @real_name : String)
      super(name, args, body, nil, nil, nil)
      @varargs = false
    end

    def mangled_name(program, obj_type)
      real_name
    end

    def compatible_with?(other)
      return false if args.size != other.args.size
      return false if varargs != other.varargs

      args.each_with_index do |arg, i|
        return false if arg.type != other.args[i].type
      end

      type == other.type
    end

    def self.for_fun(name, real_name, args, return_type, varargs, body, fun_def)
      external = External.new(name, args, body, real_name)
      external.varargs = varargs
      external.set_type(return_type)
      external.fun_def = fun_def
      external.location = fun_def.location
      external.attributes = fun_def.attributes
      fun_def.external = external
      external
    end

    def_hash @real_name, @varargs, @fun_def
  end

  class Alias < ASTNode
    property name : String
    property value : ASTNode
    property doc : String?

    def initialize(@name : String, @value : ASTNode)
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def clone_without_location
      Alias.new(@name, @value.clone)
    end

    def_equals_and_hash @name, @value
  end

  class Metaclass < ASTNode
    property name : ASTNode

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Metaclass.new(@name.clone)
    end

    def_equals_and_hash name
  end

  # obj as to
  class Cast < ASTNode
    property obj : ASTNode
    property to : ASTNode

    def initialize(@obj : ASTNode, @to : ASTNode)
    end

    def accept_children(visitor)
      @obj.accept visitor
      @to.accept visitor
    end

    def clone_without_location
      Cast.new(@obj.clone, @to.clone)
    end

    def end_location
      @end_location || @to.end_location
    end

    def_equals_and_hash @obj, @to
  end

  # typeof(exp, exp, ...)
  class TypeOf < ASTNode
    property expressions : Array(ASTNode)

    def initialize(@expressions)
    end

    def accept_children(visitor)
      @expressions.each &.accept visitor
    end

    def clone_without_location
      TypeOf.new(@expressions.clone)
    end

    def_equals_and_hash expressions
  end

  class Attribute < ASTNode
    property name : String
    property args : Array(ASTNode)
    property named_args : Array(NamedArgument)?
    property doc : String?

    def initialize(@name, @args = [] of ASTNode, @named_args = nil)
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @named_args.try &.each &.accept visitor
    end

    def clone_without_location
      Attribute.new(name, @args.clone, @named_args.clone)
    end

    def self.any?(attributes, name)
      !!(attributes.try &.any? { |attr| attr.name == name })
    end

    def_equals_and_hash name, args, named_args
  end

  # A macro expression,
  # surrounded by {{ ... }} (output = true)
  # or by {% ... %} (output = false)
  class MacroExpression < ASTNode
    property exp : ASTNode
    property output : Bool

    def initialize(@exp : ASTNode, @output = true)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def clone_without_location
      MacroExpression.new(@exp.clone, @output)
    end

    def_equals_and_hash exp, output
  end

  # Free text that is part of a macro
  class MacroLiteral < ASTNode
    property value : String

    def initialize(@value : String)
    end

    def clone_without_location
      self
    end

    def_equals_and_hash value
  end

  # if inside a macro
  #
  #     {% 'if' cond %}
  #       then
  #     {% 'else' %}
  #       else
  #     {% 'end' %}
  class MacroIf < ASTNode
    property cond : ASTNode
    property then : ASTNode
    property else : ASTNode

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      MacroIf.new(@cond.clone, @then.clone, @else.clone)
    end

    def_equals_and_hash @cond, @then, @else
  end

  # for inside a macro:
  #
  #    {% for x1, x2, ... , xn in exp %}
  #      body
  #    {% end %}
  class MacroFor < ASTNode
    property vars : Array(Var)
    property exp : ASTNode
    property body : ASTNode

    def initialize(@vars, @exp, @body)
    end

    def accept_children(visitor)
      @vars.each &.accept visitor
      @exp.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      MacroFor.new(@vars.clone, @exp.clone, @body.clone)
    end

    def_equals_and_hash @vars, @exp, @body
  end

  # A uniquely named variable inside a macro (like %var)
  class MacroVar < ASTNode
    property name : String
    property exps : Array(ASTNode)?

    def initialize(@name : String, @exps = nil)
    end

    def accept_children(visitor)
      @exps.try &.each &.accept visitor
    end

    def clone_without_location
      MacroVar.new(@name, @exps.clone)
    end

    def_equals_and_hash @name, @exps
  end

  # An underscore matches against any type
  class Underscore < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      Underscore.new
    end

    def hash
      0
    end
  end

  class Splat < UnaryExpression
    def clone_without_location
      Splat.new(@exp.clone)
    end
  end

  class MagicConstant < ASTNode
    property name : Symbol

    def initialize(@name : Symbol)
    end

    def clone_without_location
      MagicConstant.new(@name)
    end

    def expand_node(location)
      case name
      when :__LINE__
        MagicConstant.expand_line_node(location)
      when :__FILE__
        MagicConstant.expand_file_node(location)
      when :__DIR__
        MagicConstant.expand_dir_node(location)
      else
        raise "Bug: unknown magic constant: #{name}"
      end
    end

    def self.expand_line_node(location)
      NumberLiteral.new(expand_line(location))
    end

    def self.expand_line(location)
      location.try(&.line_number) || 0
    end

    def self.expand_file_node(location)
      StringLiteral.new(expand_file(location))
    end

    def self.expand_file(location)
      location.try(&.filename.to_s) || "?"
    end

    def self.expand_dir_node(location)
      StringLiteral.new(expand_dir(location))
    end

    def self.expand_dir(location)
      location.try(&.dirname) || "?"
    end

    def_equals_and_hash name
  end

  class Asm < ASTNode
    property text : String
    property output : AsmOperand?
    property inputs : Array(AsmOperand)?
    property clobbers : Array(String)?
    property volatile : Bool
    property alignstack : Bool
    property intel : Bool

    def initialize(@text, @output = nil, @inputs = nil, @clobbers = nil, @volatile = false, @alignstack = false, @intel = false)
    end

    def accept_children(visitor)
      @output.try &.accept visitor
      @inputs.try &.each &.accept visitor
    end

    def clone_without_location
      Asm.new(@text, @output.clone, @inputs.clone, @clobbers, @volatile, @alignstack, @intel)
    end

    def_equals_and_hash text, output, inputs, clobbers, volatile, alignstack, intel
  end

  class AsmOperand < ASTNode
    property constraint : String
    property exp : ASTNode

    def initialize(@constraint : String, @exp : ASTNode)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def clone_without_location
      AsmOperand.new(@constraint, @exp)
    end

    def_equals_and_hash constraint, exp
  end

  # Fictitious node to represent an id inside a macro
  class MacroId < ASTNode
    property value : String

    def initialize(@value)
    end

    def to_macro_id
      @value
    end

    def clone_without_location
      self
    end

    def_equals_and_hash value
  end

  # Fictitious node that means "all these nodes come from this file"
  class FileNode < ASTNode
    property node : ASTNode
    property filename : String

    def initialize(@node : ASTNode, @filename : String)
    end

    def accept_children(visitor)
      @node.accept visitor
    end

    def clone_without_location
      self
    end

    def_equals_and_hash node, filename
  end

  enum Visibility : Int8
    Public
    Protected
    Private
  end
end

require "./to_s"
