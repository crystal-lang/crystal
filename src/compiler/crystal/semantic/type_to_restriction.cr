require "../types"

module Crystal
  module TypeToRestriction
    def self.convert(type : NilType)
      Path.global("Nil")
    end

    def self.convert(type : BoolType)
      Path.global("Bool")
    end

    def self.convert(type : CharType)
      Path.global("Char")
    end

    def self.convert(type : SymbolType)
      Path.global("Symbol")
    end

    def self.convert(type : IntegerType | FloatType)
      case type.kind
      in NumberKind::I8   then Path.global("Int8")
      in NumberKind::I16  then Path.global("Int16")
      in NumberKind::I32  then Path.global("Int32")
      in NumberKind::I64  then Path.global("Int64")
      in NumberKind::I128 then Path.global("Int128")
      in NumberKind::U8   then Path.global("UInt8")
      in NumberKind::U16  then Path.global("UInt16")
      in NumberKind::U32  then Path.global("UInt32")
      in NumberKind::U64  then Path.global("UInt64")
      in NumberKind::U128 then Path.global("UInt128")
      in NumberKind::F32  then Path.global("Float32")
      in NumberKind::F64  then Path.global("Float64")
      end
    end

    def self.convert(type : NonGenericClassType | NonGenericModuleType | EnumType)
      return nil if type.private?

      names = [] of String
      append_namespace(type, names)
      names << type.name
      Path.global(names)
    end

    def self.convert(type : TupleInstanceType)
      Generic.new(
        Path.global("Tuple"),
        type.tuple_types.map do |tuple_type|
          convert(tuple_type) || Underscore.new
        end
      )
    end

    def self.convert(type : NamedTupleInstanceType)
      Generic.new(
        Path.global("NamedTuple"),
        type_vars: [] of ASTNode,
        named_args: type.entries.map do |entry|
          NamedArgument.new(
            entry.name,
            convert(entry.type) || Underscore.new,
          )
        end
      )
    end

    def self.convert(type : ProcInstanceType)
      type_vars = Array(ASTNode).new(type.arg_types.size + 1)
      type.arg_types.each do |arg_type|
        type_vars.push(convert(arg_type) || Underscore.new)
      end

      if type.return_type.is_a?(NilType)
        # Because there's some strange autocasting for Procs that return Nil,
        # it's better if we don't do anything fancy here.
        type_vars.push(Underscore.new)
      else
        type_vars.push(convert(type.return_type) || Underscore.new)
      end

      Generic.new(
        Path.global("Proc"),
        type_vars: type_vars,
      )
    end

    def self.convert(type : GenericInstanceType)
      return nil if type.private?

      generic_type = type.generic_type
      names = [] of String
      append_namespace(generic_type, names)
      names << generic_type.name
      path = Path.global(names)
      type_vars = type.type_vars.map do |name, type_var|
        type_var_type = type_var.type?
        if type_var_type
          convert(type_var_type) || Underscore.new
        else
          Underscore.new
        end
      end
      Generic.new(path, type_vars)
    end

    def self.convert(type : UnionType)
      Union.new(
        type.union_types.map do |union_type|
          restriction = convert(union_type)
          return unless restriction

          restriction.as(ASTNode)
        end
      )
    end

    def self.convert(type : Type)
      nil
    end

    private def self.append_namespace(type, names)
      namespace = type.namespace
      return if namespace.is_a?(Program)

      append_namespace(namespace, names)
      names << namespace.name
    end
  end
end
