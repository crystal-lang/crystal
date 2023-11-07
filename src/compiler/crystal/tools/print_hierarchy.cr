require "set"
require "colorize"
require "../syntax/ast"

module Crystal
  def self.print_hierarchy(program, io, exp, format)
    case format
    when "text"
      TextHierarchyPrinter.new(program, io, exp).execute
    when "json"
      JSONHierarchyPrinter.new(program, io, exp).execute
    else
      raise "Unknown hierarchy format: #{format}"
    end
  end

  abstract class HierarchyPrinter
    abstract def print_all

    @llvm_typer : LLVMTyper

    def initialize(@program : Program, exp : String?)
      @exp = exp ? Regex.new(exp) : nil
      @targets = Set(Type).new
      @llvm_typer = @program.llvm_typer
    end

    def execute
      if exp = @exp
        compute_targets(@program.types, exp, false)
      end

      print_all
    end

    def compute_targets(types : Array, exp, must_include = false)
      outer_must_include = must_include
      types.each do |type|
        must_include |= compute_target type, exp, outer_must_include
      end
      must_include
    end

    def compute_targets(types : Hash, exp, must_include = false)
      outer_must_include = must_include
      types.each_value do |type|
        must_include |= compute_target type, exp, outer_must_include
      end
      must_include
    end

    def compute_target(type : NonGenericClassType, exp, must_include)
      if must_include || (type.full_name =~ exp)
        @targets << type
        must_include = true
      end

      compute_targets type.types, exp, false

      subtypes = type.subclasses.reject(GenericClassInstanceType)
      must_include |= compute_targets subtypes, exp, must_include
      if must_include
        @targets << type
      end
      must_include
    end

    def compute_target(type : GenericClassType, exp, must_include)
      if must_include || (type.full_name =~ exp)
        @targets << type
        must_include = true
      end

      compute_targets type.types, exp, false
      compute_targets type.instantiated_types, exp, must_include

      subtypes = type.subclasses.reject(GenericClassInstanceType)
      must_include |= compute_targets subtypes, exp, must_include
      if must_include
        @targets << type
      end
      must_include
    end

    def compute_target(type : GenericClassInstanceType, exp, must_include)
      if must_include
        @targets << type
        must_include = true
      end
      must_include
    end

    def compute_target(type, exp, must_include)
      false
    end

    def must_print?(type : NonGenericClassType | GenericClassType)
      !@exp || @targets.includes?(type)
    end

    def must_print?(type)
      false
    end

    def type_size(type)
      return nil unless constant_type_size?(type)

      if type.is_a?(GenericClassType)
        # obtain a "generic instance" where all arguments are simply the unbound
        # parameters themselves; if we are here, `LLVMTyper` should never be
        # requesting the size of a `TypeParameter`
        type_vars = type.type_vars.map { |type_var| type.type_parameter(type_var).as(TypeVar) }
        type = type.instantiate(type_vars)
      end

      llvm_type =
        case type
        when PointerInstanceType, ProcInstanceType
          @llvm_typer.llvm_type(type, wants_size: true)
        when InstanceVarContainer
          @llvm_typer.llvm_struct_type(type, wants_size: true)
        else
          @llvm_typer.llvm_type(type, wants_size: true)
        end

      @llvm_typer.size_of(llvm_type)
    end

    def ivar_size(ivar, extern)
      return nil unless constant_ivar_size?(ivar.type)

      llvm_type = if extern
                    @llvm_typer.llvm_embedded_c_type(ivar.type, wants_size: true)
                  else
                    @llvm_typer.llvm_embedded_type(ivar.type, wants_size: true)
                  end

      @llvm_typer.size_of(llvm_type)
    end

    # Returns `true` if `type`'s size (`sizeof` for values, `instance_sizeof`
    # for references) is a constant, in particular if it doesn't depend on
    # `type`'s generic type parameters. `type` is never a generic instance.
    def constant_type_size?(type)
      case type
      when GenericUnionType, StaticArrayType, TupleType, NamedTupleType
        false
      when PointerType, ProcType
        true
      when GenericClassType
        type.all_instance_vars.each do |_, ivar|
          return false unless ivar_type = ivar.type?
          return false unless constant_ivar_size?(ivar_type)
        end
        true
      else
        true
      end
    end

    # Returns `true` if `sizeof(type)` is a constant, in particular if it
    # doesn't depend on `type`'s generic type parameters. Unlike
    # `#constant_type_size?`, here `type` can be a generic instance, but not an
    # uninstantiated generic.
    def constant_ivar_size?(type)
      return true unless type.unbound? || type.is_a?(GenericType)

      case type
      when GenericType
        type_vars = type.type_vars.map { |type_var| type.type_parameter(type_var).as(TypeVar) }
        constant_ivar_size?(type.instantiate(type_vars))
      when TypeParameter
        false
      when MixedUnionType
        type.union_types.all? { |t| constant_ivar_size?(t) }
      when StaticArrayInstanceType
        return false unless constant_ivar_size?(type.element_type)
        case size_var = type.size
        when NumberLiteral
          true
        when Var
          return false unless size_var_type = size_var.type?
          return false unless constant_ivar_size?(size_var_type)
        else
          false
        end
      when TupleInstanceType
        type.tuple_types.all? { |t| constant_ivar_size?(t) }
      when NamedTupleInstanceType
        type.entries.all? { |entry| constant_ivar_size?(entry.type) }
      when GenericModuleInstanceType
        # TODO: verify
        type.generic_type.each_instantiated_type do |instance|
          instance.as(GenericModuleInstanceType).raw_including_types.try &.each do |including_type|
            return false unless constant_ivar_size?(including_type)
          end
        end
        true
      when InstanceVarContainer
        if type.struct?
          type.all_instance_vars.each do |_, ivar|
            return false unless ivar_type = ivar.type?
            return false unless constant_ivar_size?(ivar_type)
          end
        end
        true
      else
        true
      end
    end
  end

  class TextHierarchyPrinter < HierarchyPrinter
    def initialize(program : Program, @io : IO, exp : String?)
      super(program, exp)
      @indents = [] of Bool
    end

    def print_all
      with_color.light_gray.bold.surround(@io) do
        print_type @program.object
      end
    end

    def print_subtypes(types)
      types = types.sort_by &.to_s
      types.each_with_index do |type, i|
        if i == types.size - 1
          @indents[-1] = false
        end
        print_subtype type
      end
    end

    def print_subtype(type)
      return unless must_print? type

      unless @indents.empty?
        print_indent
        @io << "|\n"
      end

      print_type type
    end

    def print_type_name(type)
      print_indent
      @io << "+" unless @indents.empty?
      @io << "- " << (type.struct? ? "struct" : "class") << " " << type

      if type_size = type_size(type)
        with_color.light_gray.surround(@io) do
          @io << " (" << type_size << " bytes)"
        end
      end
      @io << '\n'
    end

    def print_type(type : GenericClassType | NonGenericClassType | GenericClassInstanceType)
      print_type_name type

      subtypes = type.subclasses.select { |sub| must_print?(sub) }
      print_instance_vars type, !subtypes.empty?

      with_indent do
        print_subtypes subtypes
      end
    end

    def print_type(type)
      # Nothing to do
    end

    def print_instance_vars(type, has_subtypes)
      instance_vars = type.instance_vars
      return if instance_vars.empty?

      instance_vars = instance_vars.values
      instance_var_types = {} of MetaTypeVar => {Type, UInt64?}
      instance_vars.each do |ivar|
        if ivar_type = ivar.type?
          instance_var_types[ivar] = {ivar_type, ivar_size(ivar, type.extern?)}
        end
      end

      max_name_size = instance_vars.max_of &.name.size

      max_type_size = instance_var_types.max_of? { |_, (type, _)| type.to_s.size } || 0
      max_bytes_size = instance_var_types.max_of? { |_, (_, size)| size.try(&.to_s.size) || 0 } || 0

      instance_vars.each do |ivar|
        print_indent
        @io << (@indents.last ? "|" : " ") << (has_subtypes ? "  .   " : "      ")

        with_color.light_gray.surround(@io) do
          ivar.name.ljust(@io, max_name_size)
          @io << " : "
          if entry = instance_var_types[ivar]?
            ivar_type, size = entry
            if size
              ivar_type.to_s.ljust(@io, max_type_size)
              with_color.light_gray.surround(@io) do
                @io << " ("
                size.to_s.rjust(@io, max_bytes_size)
                @io << " bytes)"
              end
            else
              @io << ivar_type
            end
          else
            @io << "MISSING".colorize.red.bright
          end
        end
        @io << '\n'
      end
    end

    def print_indent
      unless @indents.empty?
        @io << "  "
        0.upto(@indents.size - 2) do |i|
          indent = @indents[i]
          if indent
            @io << "|  "
          else
            @io << "   "
          end
        end
      end
    end

    def with_indent(&)
      @indents.push true
      yield
      @indents.pop
    end

    def with_color
      Colorize.with.toggle(@program.color?)
    end
  end

  class JSONHierarchyPrinter < HierarchyPrinter
    def initialize(program : Program, io : IO, exp : String?)
      super(program, exp)
      @json = JSON::Builder.new(io)
    end

    def print_all
      @json.document do
        @json.object do
          print_type(@program.object)
        end
      end
    end

    def print_subtypes(types)
      types = types.sort_by &.to_s

      @json.field "sub_types" do
        @json.array do
          types.each do |type|
            if must_print? type
              @json.object do
                print_type(type)
              end
            end
          end
        end
      end
    end

    def print_type_name(type)
      @json.field "name", type.to_s
      @json.field "kind", type.struct? ? "struct" : "class"

      if type_size = type_size(type)
        @json.field "size_in_bytes", type_size(type)
      end
    end

    def print_type(type : GenericClassType | NonGenericClassType | GenericClassInstanceType)
      print_type_name(type)
      subtypes = type.subclasses.select { |sub| must_print?(sub) }

      print_instance_vars(type, !subtypes.empty?)
      print_subtypes(subtypes)
    end

    def print_type(type)
      # Nothing to do
    end

    def print_instance_vars(type, has_subtypes)
      instance_vars = type.instance_vars
      return if instance_vars.empty?

      instance_vars = instance_vars.values
      @json.field "instance_vars" do
        @json.array do
          instance_vars.each do |instance_var|
            if ivar_type = instance_var.type?
              @json.object do
                @json.field "name", instance_var.name.to_s
                @json.field "type", ivar_type.to_s
                if ivar_size = ivar_size(instance_var, type.extern?)
                  @json.field "size_in_bytes", ivar_size
                end
              end
            end
          end
        end
      end
    end
  end
end
