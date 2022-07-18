require "../types"

module Crystal
  # Allows converting a type to a restriction from the context a given type.
  struct TypeToRestriction
    # Initializes this converter to convert types relative to the given type.
    def initialize(@from_type : Type)
    end

    def ident_pool
      @from_type.ident_pool
    end

    def convert(type : NilType)
      Path.global(ident_pool._Nil)
    end

    def convert(type : VoidType)
      Path.global(ident_pool._Void)
    end

    def convert(type : BoolType)
      Path.global(ident_pool._Bool)
    end

    def convert(type : CharType)
      Path.global(ident_pool._Char)
    end

    def convert(type : SymbolType)
      Path.global(ident_pool._Symbol)
    end

    def convert(type : IntegerType | FloatType)
      case type.kind
      in NumberKind::I8   then Path.global(ident_pool._Int8)
      in NumberKind::I16  then Path.global(ident_pool._Int16)
      in NumberKind::I32  then Path.global(ident_pool._Int32)
      in NumberKind::I64  then Path.global(ident_pool._Int64)
      in NumberKind::I128 then Path.global(ident_pool._Int128)
      in NumberKind::U8   then Path.global(ident_pool._UInt8)
      in NumberKind::U16  then Path.global(ident_pool._UInt16)
      in NumberKind::U32  then Path.global(ident_pool._UInt32)
      in NumberKind::U64  then Path.global(ident_pool._UInt64)
      in NumberKind::U128 then Path.global(ident_pool._UInt128)
      in NumberKind::F32  then Path.global(ident_pool._Float32)
      in NumberKind::F64  then Path.global(ident_pool._Float64)
      end
    end

    def convert(type : NonGenericClassType |
                       NonGenericModuleType |
                       EnumType |
                       AliasType |
                       TypeDefType)
      type_to_path(type)
    end

    def convert(type : TupleInstanceType)
      Generic.new(
        Path.global(ident_pool._Tuple),
        type.tuple_types.map do |tuple_type|
          convert(tuple_type) || Underscore.new
        end
      )
    end

    def convert(type : NamedTupleInstanceType)
      Generic.new(
        Path.global(ident_pool._NamedTuple),
        type_vars: [] of ASTNode,
        named_args: type.entries.map do |entry|
          NamedArgument.new(
            entry.name,
            convert(entry.type) || Underscore.new,
          )
        end
      )
    end

    def convert(type : ProcInstanceType)
      inputs =
        type.arg_types.map do |arg_type|
          convert(arg_type) || Underscore.new
        end

      output =
        if type.return_type.is_a?(NilType)
          # Because there's some strange autocasting for Procs that return Nil,
          # it's better if we don't do anything fancy here.
          Underscore.new
        else
          convert(type.return_type) || Underscore.new
        end

      ProcNotation.new(inputs, output)
    end

    def convert(type : GenericInstanceType)
      generic_type = type.generic_type
      path = type_to_path(type.generic_type)
      type_vars = type.type_vars.map do |name, type_var|
        if type_var.is_a?(NumberLiteral)
          type_var.clone
        elsif type_var_type = type_var.type?
          convert(type_var_type) || Underscore.new
        else
          Underscore.new
        end
      end
      Generic.new(path, type_vars)
    end

    def convert(type : UnionType)
      Union.new(
        type.union_types.map do |union_type|
          restriction = convert(union_type)
          return unless restriction

          restriction.as(ASTNode)
        end
      )
    end

    def convert(type : MetaclassType)
      restriction = convert(type.instance_type)
      return unless restriction

      Metaclass.new(restriction)
    end

    def convert(type : TypeParameter)
      Path.new(type.name)
    end

    def convert(type : NoReturnType)
      Path.global(ident_pool._NoReturn)
    end

    def convert(type : VirtualType)
      convert(type.base_type)
    end

    def convert(type : VirtualMetaclassType |
                       GenericClassInstanceMetaclassType |
                       GenericModuleInstanceMetaclassType)
      converted = convert(type.instance_type)
      converted ? Metaclass.new(converted) : nil
    end

    def convert(type : TypeSplat)
      converted = convert(type.splatted_type)
      converted ? Splat.new(converted) : nil
    end

    # These can't happen as instance var types
    def convert(type : Crystal::GenericClassType |
                       Crystal::GenericModuleType |
                       Crystal::LibType |
                       Crystal::AnnotationType |
                       Crystal::Const |
                       Crystal::NumberAutocastType |
                       Crystal::SymbolAutocastType)
      nil
    end

    private def type_to_path(type)
      common_namespace =
        if fully_public?(type)
          # If the type if fully public we can fully qualify the restriction
          nil
        else
          # Otherwise, we need to use a relative path starting from `from_type`
          common_namespace(type, @from_type)
        end

      names = [] of Ident
      append_namespace(type, names, upto: common_namespace)
      names << type.name

      Path.new(names, global: !common_namespace)
    end

    private def common_namespace(type, from_type)
      while true
        return nil if type.is_a?(Program)

        # If from_type is Foo::Bar and type is Foo::Bar::Baz
        # we want to say that the common namespace Foo::Bar
        return type if type == from_type

        # If from_type is Foo::Bar and type is Foo::Baz
        # we want to say that the common namespace is Foo
        return type if type == from_type.namespace

        type = type.namespace
      end
    end

    private def append_namespace(type, names, upto = nil)
      namespace = type.namespace
      return if namespace.is_a?(Program)
      return if namespace == upto

      append_namespace(namespace, names, upto)
      names << namespace.name
    end

    private def fully_public?(type)
      return true if type.is_a?(Program)

      !type.private? && fully_public?(type.namespace)
    end
  end
end
