module Crystal
  class Program
    @macro_types = {} of String => MacroType

    # Defines the hierarchy of built-in AST node types. These types should
    # mirror the structure of `../macros.cr`, plus all types that are available
    # in the macro language, even if they have no macro methods defined yet.
    private def define_macro_types
      @macro_types["ASTNode"] = @ast_node = ast_node = NonGenericMacroType.new self, "ASTNode", nil

      @macro_types["Nop"] = NonGenericMacroType.new self, "Nop", ast_node
      @macro_types["NilLiteral"] = NonGenericMacroType.new self, "NilLiteral", ast_node
      @macro_types["BoolLiteral"] = NonGenericMacroType.new self, "BoolLiteral", ast_node
      @macro_types["NumberLiteral"] = NonGenericMacroType.new self, "NumberLiteral", ast_node
      @macro_types["CharLiteral"] = NonGenericMacroType.new self, "CharLiteral", ast_node
      @macro_types["StringLiteral"] = NonGenericMacroType.new self, "StringLiteral", ast_node
      @macro_types["StringInterpolation"] = NonGenericMacroType.new self, "StringInterpolation", ast_node
      @macro_types["SymbolLiteral"] = NonGenericMacroType.new self, "SymbolLiteral", ast_node
      @macro_types["ArrayLiteral"] = NonGenericMacroType.new self, "ArrayLiteral", ast_node
      @macro_types["HashLiteral"] = NonGenericMacroType.new self, "HashLiteral", ast_node
      @macro_types["NamedTupleLiteral"] = NonGenericMacroType.new self, "NamedTupleLiteral", ast_node
      @macro_types["RangeLiteral"] = NonGenericMacroType.new self, "RangeLiteral", ast_node
      @macro_types["RegexLiteral"] = NonGenericMacroType.new self, "RegexLiteral", ast_node
      @macro_types["TupleLiteral"] = NonGenericMacroType.new self, "TupleLiteral", ast_node

      # Crystal::MetaMacroVar
      @macro_types["MetaVar"] = NonGenericMacroType.new self, "MetaVar", ast_node

      @macro_types["Annotation"] = NonGenericMacroType.new self, "Annotation", ast_node
      @macro_types["Var"] = NonGenericMacroType.new self, "Var", ast_node
      @macro_types["Block"] = NonGenericMacroType.new self, "Block", ast_node
      @macro_types["Expressions"] = NonGenericMacroType.new self, "Expressions", ast_node
      @macro_types["Call"] = NonGenericMacroType.new self, "Call", ast_node
      @macro_types["NamedArgument"] = NonGenericMacroType.new self, "NamedArgument", ast_node
      @macro_types["If"] = NonGenericMacroType.new self, "If", ast_node
      @macro_types["Assign"] = NonGenericMacroType.new self, "Assign", ast_node
      @macro_types["MultiAssign"] = NonGenericMacroType.new self, "MultiAssign", ast_node
      @macro_types["InstanceVar"] = NonGenericMacroType.new self, "InstanceVar", ast_node
      @macro_types["ReadInstanceVar"] = NonGenericMacroType.new self, "ReadInstanceVar", ast_node
      @macro_types["ClassVar"] = NonGenericMacroType.new self, "ClassVar", ast_node
      @macro_types["Global"] = NonGenericMacroType.new self, "Global", ast_node

      @macro_types["BinaryOp"] = binary_op = NonGenericMacroType.new self, "BinaryOp", ast_node
      @macro_types["And"] = NonGenericMacroType.new self, "And", binary_op
      @macro_types["Or"] = NonGenericMacroType.new self, "Or", binary_op

      @macro_types["Arg"] = NonGenericMacroType.new self, "Arg", ast_node
      @macro_types["ProcNotation"] = NonGenericMacroType.new self, "ProcNotation", ast_node
      @macro_types["Def"] = NonGenericMacroType.new self, "Def", ast_node
      @macro_types["Macro"] = NonGenericMacroType.new self, "Macro", ast_node

      @macro_types["UnaryExpression"] = unary_expression = NonGenericMacroType.new self, "UnaryExpression", ast_node
      @macro_types["Not"] = NonGenericMacroType.new self, "Not", unary_expression
      @macro_types["PointerOf"] = NonGenericMacroType.new self, "PointerOf", unary_expression
      @macro_types["SizeOf"] = NonGenericMacroType.new self, "SizeOf", unary_expression
      @macro_types["InstanceSizeOf"] = NonGenericMacroType.new self, "InstanceSizeOf", unary_expression
      @macro_types["Out"] = NonGenericMacroType.new self, "Out", unary_expression
      @macro_types["Splat"] = NonGenericMacroType.new self, "Splat", unary_expression
      @macro_types["DoubleSplat"] = NonGenericMacroType.new self, "DoubleSplat", unary_expression

      @macro_types["OffsetOf"] = NonGenericMacroType.new self, "OffsetOf", ast_node
      @macro_types["VisibilityModifier"] = NonGenericMacroType.new self, "VisibilityModifier", ast_node
      @macro_types["IsA"] = NonGenericMacroType.new self, "IsA", ast_node
      @macro_types["RespondsTo"] = NonGenericMacroType.new self, "RespondsTo", ast_node
      @macro_types["Require"] = NonGenericMacroType.new self, "Require", ast_node
      @macro_types["When"] = NonGenericMacroType.new self, "When", ast_node
      @macro_types["Case"] = NonGenericMacroType.new self, "Case", ast_node
      @macro_types["ImplicitObj"] = NonGenericMacroType.new self, "ImplicitObj", ast_node
      @macro_types["Path"] = NonGenericMacroType.new self, "Path", ast_node
      @macro_types["ClassDef"] = NonGenericMacroType.new self, "ClassDef", ast_node
      @macro_types["While"] = NonGenericMacroType.new self, "While", ast_node
      @macro_types["Generic"] = NonGenericMacroType.new self, "Generic", ast_node
      @macro_types["TypeDeclaration"] = NonGenericMacroType.new self, "TypeDeclaration", ast_node
      @macro_types["UninitializedVar"] = NonGenericMacroType.new self, "UninitializedVar", ast_node
      @macro_types["Rescue"] = NonGenericMacroType.new self, "Rescue", ast_node
      @macro_types["ExceptionHandler"] = NonGenericMacroType.new self, "ExceptionHandler", ast_node
      @macro_types["ProcLiteral"] = NonGenericMacroType.new self, "ProcLiteral", ast_node
      @macro_types["ProcPointer"] = NonGenericMacroType.new self, "ProcPointer", ast_node
      @macro_types["Union"] = NonGenericMacroType.new self, "Union", ast_node

      @macro_types["ControlExpression"] = control_expression = NonGenericMacroType.new self, "ControlExpression", ast_node
      @macro_types["Return"] = NonGenericMacroType.new self, "Return", control_expression
      @macro_types["Break"] = NonGenericMacroType.new self, "Break", control_expression
      @macro_types["Next"] = NonGenericMacroType.new self, "Next", control_expression

      @macro_types["Yield"] = NonGenericMacroType.new self, "Yield", ast_node
      @macro_types["Metaclass"] = NonGenericMacroType.new self, "Metaclass", ast_node
      @macro_types["Cast"] = NonGenericMacroType.new self, "Cast", ast_node
      @macro_types["NilableCast"] = NonGenericMacroType.new self, "NilableCast", ast_node
      @macro_types["MacroId"] = NonGenericMacroType.new self, "MacroId", ast_node
      @macro_types["TypeNode"] = NonGenericMacroType.new self, "TypeNode", ast_node

      # bottom type
      @macro_types["NoReturn"] = @macro_no_return = NoReturnMacroType.new self

      # unimplemented types (see https://github.com/crystal-lang/crystal/issues/3274#issuecomment-860092436)
      @macro_types["Self"] = NonGenericMacroType.new self, "Self", ast_node
      @macro_types["Underscore"] = NonGenericMacroType.new self, "Underscore", ast_node
      @macro_types["Select"] = NonGenericMacroType.new self, "Select", ast_node
      @macro_types["Asm"] = NonGenericMacroType.new self, "Asm", ast_node
      @macro_types["AsmOperand"] = NonGenericMacroType.new self, "AsmOperand", ast_node
      @macro_types["MagicConstant"] = NonGenericMacroType.new self, "MagicConstant", ast_node
      @macro_types["Primitive"] = NonGenericMacroType.new self, "Primitive", ast_node
      @macro_types["TypeOf"] = NonGenericMacroType.new self, "TypeOf", ast_node
      @macro_types["AnnotationDef"] = NonGenericMacroType.new self, "AnnotationDef", ast_node
      @macro_types["CStructOrUnionDef"] = NonGenericMacroType.new self, "CStructOrUnionDef", ast_node
      @macro_types["EnumDef"] = NonGenericMacroType.new self, "EnumDef", ast_node
      @macro_types["FunDef"] = NonGenericMacroType.new self, "FunDef", ast_node
      @macro_types["LibDef"] = NonGenericMacroType.new self, "LibDef", ast_node
      @macro_types["ModuleDef"] = NonGenericMacroType.new self, "ModuleDef", ast_node
      @macro_types["Alias"] = NonGenericMacroType.new self, "Alias", ast_node
      @macro_types["Extend"] = NonGenericMacroType.new self, "Extend", ast_node
      @macro_types["ExternalVar"] = NonGenericMacroType.new self, "ExternalVar", ast_node
      @macro_types["Include"] = NonGenericMacroType.new self, "Include", ast_node
      @macro_types["TypeDef"] = NonGenericMacroType.new self, "TypeDef", ast_node
      @macro_types["MacroExpression"] = NonGenericMacroType.new self, "MacroExpression", ast_node
      @macro_types["MacroFor"] = NonGenericMacroType.new self, "MacroFor", ast_node
      @macro_types["MacroIf"] = NonGenericMacroType.new self, "MacroIf", ast_node
      @macro_types["MacroLiteral"] = NonGenericMacroType.new self, "MacroLiteral", ast_node
      @macro_types["MacroVar"] = NonGenericMacroType.new self, "MacroVar", ast_node
      @macro_types["MacroVerbatim"] = NonGenericMacroType.new self, "MacroVerbatim", unary_expression
    end

    # Returns the macro type for a given AST node. This association is done
    # through `Crystal::ASTNode#class_desc`.
    def node_macro_type(node : ASTNode) : MacroType
      @macro_types[node.class_desc]
    end

    # Returns the macro type named by a given AST node in the macro language.
    def lookup_macro_type(name : Path)
      if name.names.size == 1
        macro_type = @macro_types[name.names.first]?
      end
      macro_type || macro_no_return
    end

    def lookup_macro_type(name : Union)
      MacroType.union(self, name.types.map { |type| lookup_macro_type(type) })
    end

    def lookup_macro_type(name : ASTNode)
      macro_no_return
    end

    def ast_node
      @ast_node.not_nil!
    end

    def macro_no_return
      @macro_no_return.not_nil!
    end
  end

  # An AST node type in the macro language, used in places such as
  # `ASTNode#is_a?` that expect an AST node type instead of a "regular" type.
  abstract class MacroType
    getter program : Program

    def initialize(@program)
    end
  end

  # An AST node type that cannot be generic, e.g. `NumberLiteral`.
  class NonGenericMacroType < MacroType
    getter name : String
    getter parent : MacroType?

    def initialize(program, @name, @parent)
      super(program)
    end

    def to_s(io : IO) : Nil
      io << @name
    end
  end

  # The bottom type of AST nodes. No AST nodes are of this type. Meaningful as
  # a return type, e.g. `::raise`.
  class NoReturnMacroType < MacroType
    def to_s(io : IO) : Nil
      io << "NoReturn"
    end
  end

  # An irreducible union of 2 or more AST node types.
  class UnionMacroType < MacroType
    getter union_macro_types : Array(MacroType)

    def initialize(program, @union_macro_types)
      super(program)
    end

    def to_s(io : IO) : Nil
      io << '('
      @union_macro_types.join(io, " | ")
      io << ')'
    end
  end

  class MacroType
    # Returns true if *macro_type* is a subtype of *other*; that is, every AST
    # node instance of *macro_type* is also an instance of *other*.
    def self.subtype?(macro_type : NonGenericMacroType, other : NonGenericMacroType)
      return true if macro_type == other
      parent = macro_type.parent
      !parent.nil? && subtype?(parent, other)
    end

    def self.subtype?(macro_type : NoReturnMacroType, other : MacroType)
      true
    end

    def self.subtype?(macro_type : UnionMacroType, other : MacroType)
      macro_type.union_macro_types.all? { |union_type| subtype?(union_type, other) }
    end

    def self.subtype?(macro_type : MacroType, other : UnionMacroType)
      other.union_macro_types.any? { |union_type| subtype?(macro_type, union_type) }
    end

    def self.subtype?(macro_type : MacroType, other : MacroType)
      false
    end

    # Returns the union of the given macro *types*. Additionally reduces the
    # variant types so that:
    #
    # * There are no duplicate variant types;
    # * `NoReturn` is not among the variant types, unless the union is empty;
    # * No variant type is a subtype of another variant type.
    #
    # This is analogous to `Program#type_merge_union_of` for regular types. The
    # returned macro type is a `UnionMacroType` only if there are 2 or more
    # variant types.
    def self.union(program : Program, types : Array(MacroType)) : MacroType
      return program.macro_no_return if types.empty?

      flattened = [] of MacroType
      types.each do |type|
        case type
        when UnionMacroType
          flattened.concat(type.union_macro_types)
        when NoReturnMacroType
          # do nothing
        else
          flattened << type
        end
      end
      flattened.uniq!

      case flattened.size
      when 0
        return program.macro_no_return
      when 1
        return flattened.first
      when 2
        a, b = flattened
        return b if subtype?(a, b)
        return a if subtype?(b, a)
        merged = flattened
      else
        merged = flattened.reject do |type|
          flattened.any? do |other|
            type != other && subtype?(type, other)
          end
        end
      end

      case merged.size
      when 0
        program.macro_no_return
      when 1
        merged.first
      else
        UnionMacroType.new(program, merged)
      end
    end
  end

  class ASTNode
    def macro_is_a?(macro_type : MacroType) : Bool
      MacroType.subtype?(macro_type.program.node_macro_type(self), macro_type)
    end
  end
end
