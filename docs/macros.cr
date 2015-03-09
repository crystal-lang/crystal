module Macros
  abstract class ASTNode
  end

  class Nop < ASTNode
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
  end

  # The nil literal.
  class NilLiteral < ASTNode
  end

  # A bool literal.
  class BoolLiteral < ASTNode
  end

  # Any number literal.
  class NumberLiteral < ASTNode
  end

  # A char literal.
  class CharLiteral < ASTNode
  end

  class StringLiteral < ASTNode
  end

  class StringInterpolation < ASTNode
  end

  class SymbolLiteral < ASTNode
  end

  # An array literal.
  class ArrayLiteral < ASTNode
  end

  class HashLiteral < ASTNode
  end

  class RangeLiteral < ASTNode
  end

  class RegexLiteral < ASTNode
  end

  class TupleLiteral < ASTNode
  end

  # A local variable or block argument.
  class Var < ASTNode
  end

  # A code block.
  class Block < ASTNode
  end

  # A method call.
  class Call < ASTNode
  end

  class NamedArgument < ASTNode
  end

  # An if expression.
  class If < ASTNode
  end

  class Unless < ASTNode
  end

  # An ifdef expression.
  class IfDef < ASTNode
  end

  # Assign expression.
  class Assign < ASTNode
  end

  # Assign expression.
  class MultiAssign < ASTNode
  end

  # An instance variable.
  class InstanceVar < ASTNode
  end

  class ReadInstanceVar < ASTNode
  end

  class ClassVar < ASTNode
  end

  # A global variable.
  class Global < ASTNode
  end

  abstract class BinaryOp < ASTNode
  end

  # Expressions and.
  class And < BinaryOp
  end

  # Expressions or.
  class Or < BinaryOp
  end

  # A def argument.
  class Arg < ASTNode
  end

  class Fun < ASTNode
  end

  class BlockArg < ASTNode
  end

  # A method definition.
  class Def < ASTNode
  end

  class Macro < ASTNode
  end

  abstract class UnaryExpression < ASTNode
  end

  class Not < UnaryExpression
  end

  class PointerOf < UnaryExpression
  end

  class SizeOf < UnaryExpression
  end

  class InstanceSizeOf < UnaryExpression
  end

  class Out < UnaryExpression
  end

  class VisibilityModifier < ASTNode
  end

  class IsA < ASTNode
  end

  class RespondsTo < ASTNode
  end

  class Require < ASTNode
  end

  class When < ASTNode
  end

  class Case < ASTNode
  end

  class ImplicitObj < ASTNode
  end

  class Path < ASTNode
  end

  class ClassDef < ASTNode
  end

  class ModuleDef < ASTNode
  end

  class While < ASTNode
  end

  class Until < ASTNode
  end

  class Generic < ASTNode
  end

  class DeclareVar < ASTNode
  end

  class Rescue < ASTNode
  end

  class ExceptionHandler < ASTNode
  end

  class FunLiteral < ASTNode
  end

  class FunPointer < ASTNode
  end

  class Union < ASTNode
  end

  class Virtual < ASTNode
  end

  class Self < ASTNode
  end

  abstract class ControlExpression < ASTNode
  end

  class Return < ControlExpression
  end

  class Break < ControlExpression
  end

  class Next < ControlExpression
  end

  class Yield < ASTNode
  end

  class Include < ASTNode
  end

  class Extend < ASTNode
  end

  class Undef < ASTNode
  end

  class LibDef < ASTNode
  end

  class FunDef < ASTNode
  end

  class TypeDef < ASTNode
  end

  abstract class StructOrUnionDef < ASTNode
  end

  class StructDef < StructOrUnionDef
  end

  class UnionDef < StructOrUnionDef
  end

  class EnumDef < ASTNode
  end

  class ExternalVar < ASTNode
  end

  class Alias < ASTNode
  end

  class Metaclass < ASTNode
  end

  class Cast < ASTNode
  end

  class TypeOf < ASTNode
  end

  class Attribute < ASTNode
  end

  # A macro expression,
  # surrounded by {{ ... }} (output = true)
  # or by {% ... %} (output = false)
  class MacroExpression < ASTNode
  end

  # Free text that is part of a macro
  class MacroLiteral < ASTNode
  end

  # if inside a macro
  class MacroIf < ASTNode
  end

  # for inside a macro:
  class MacroFor < ASTNode
  end

  class Underscore < ASTNode
  end

  class Splat < UnaryExpression
  end

  class MagicConstant < ASTNode
  end

  class MacroId < ASTNode
  end

  class TypeNode < ASTNode
  end
end
