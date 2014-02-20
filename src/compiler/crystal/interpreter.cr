require "ast"
require "visitor"
require "type_inference/type_visitor_helper"

module Crystal
  class Interpreter < Visitor
    include TypeVisitorHelper

    getter value
    getter mod
    getter! scope
    getter! current_def
    getter vars

    def initialize(@mod, @scope = nil, @vars = {} of String => Value, @current_def = nil, @call = nil, @parent_interpreter = nil, @free_vars = nil)
      @value = nil_value
      @types = [@mod] of Type
    end

    def interpret(code)
      parser = Parser.new(code, [Set.new(@vars.keys)])
      nodes = parser.parse
      nodes = @mod.normalize nodes
      nodes.accept self

      @value
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : Nop)
      @value = PrimitiveValue.new(mod.nil, nil)
    end

    def visit(node : NilLiteral)
      @value = PrimitiveValue.new(mod.nil, nil)
    end

    def visit(node : BoolLiteral)
      @value = PrimitiveValue.new(mod.bool, node.value)
    end

    def visit(node : CharLiteral)
      @value = PrimitiveValue.new(mod.char, node.value)
    end

    def visit(node : NumberLiteral)
      case node.kind
      when :i8
        type = mod.int8
        value = node.value.to_i8
      when :i16
        type = mod.int16
        value = node.value.to_i16
      when :i32
        type = mod.int32
        value = node.value.to_i32
      when :i64
        type = mod.int64
        value = node.value.to_i64
      when :u8
        type = mod.uint8
        value = node.value.to_u8
      when :u16
        type = mod.uint16
        value = node.value.to_u16
      when :u32
        type = mod.uint32
        value = node.value.to_u32
      when :u64
        type = mod.uint64
        value = node.value.to_u64
      when :f32
        type = mod.float32
        value = node.value.to_f32
      when :f64
        type = mod.float64
        value = node.value.to_f64
      else
        raise "Invalid node kind: #{node.kind}"
      end
      @value = PrimitiveValue.new(type.not_nil!, value)
    end

    def visit(node : StringLiteral)
      @value = ClassValue.new(mod, mod.string,
            {
              "@length" => PrimitiveValue.new(mod.int32, node.value.length)
              "@c" => PrimitiveValue.new(mod.char, node.value[0])
            } of String => Value
          )
    end

    def visit(node : SymbolLiteral)
      @value = PrimitiveValue.new(mod.symbol, node.value)
    end

    def visit(node : Assign)
      target = node.target
      case target
      when Var
        node.value.accept self
        @vars[target.name] = @value
      when InstanceVar
        node.value.accept self
        self_value[target.name] = @value
      when Path
        type = current_type.types[target.names.first]?
        if type
          target.raise "already initialized constant #{target}"
        end

        node.value.accept self

        current_type.types[target.names.first] = ConstValue.new(@mod, current_type, @value)
      else
        raise "Assign not implemented yet: #{node}"
      end

      false
    end

    def visit(node : Var)
      @value = @vars[node.name]
    end

    def visit(node : InstanceVar)
      scope = @vars["self"] as ClassValue
      @value = scope[node.name]
    end

    def visit(node : ClassDef)
      process_class_def(node) do
        node.body.accept self
      end

      @value = nil_value

      false
    end

    def visit(node : ModuleDef)
      process_module_def(node) do
        node.body.accept self
      end

      @value = nil_value

      false
    end

    def visit(node : If)
      node.cond.accept self

      if @value.truthy?
        node.then.accept self
      else
        node.else.accept self
      end

      false
    end

    def visit(node : While)
      while true
        node.cond.accept self
        break unless @value.truthy?

        node.body.accept self
      end

      @value = nil_value
      false
    end

    def visit(node : Def)
      process_def node

      @value = nil_value

      false
    end

    def visit(node : Macro)
      process_macro node

      @value = nil_value

      false
    end

    def visit(node : Alias)
      process_alias(node)

      @value = nil_value

      false
    end

    def visit(node : Include)
      process_include(node)

      @value = nil_value

      false
    end

    def visit(node : LibDef)
      process_lib_def(node) do
        node.body.accept self
      end

      @value = nil_value

      false
    end

    def end_visit(node : TypeDef)
      process_type_def(node)
    end

    def end_visit(node : StructDef)
      process_struct_def node
    end

    def end_visit(node : UnionDef)
      process_union_def node
    end

    def visit(node : EnumDef)
      process_enum_def(node)
      false
    end

    def visit(node : ExternalVar)
      process_external_var(node)
      false
    end

    def visit(node : FunDef)
      process_fun_def(node)
      false
    end

    def end_visit(node : Union)
      process_ident_union(node)
      @value = MetaclassValue.new(node.type)
    end

    def end_visit(node : Hierarchy)
      process_hierarchy(node)
      @value = MetaclassValue.new(node.type)
    end

    def visit(node : TypeOf)
      types = [] of Type
      node.expressions.each do |exp|
        exp.accept self
        types << @value.type
      end

      node.type = @mod.type_merge(types)
      @value = MetaclassValue.new(node.type)
    end

    def end_visit(node : NewGenericClass)
      process_new_generic_class(node)
      @value = MetaclassValue.new(node.type)
    end

    def visit(node : DeclareVar)
      # Nothing to do (yet)
      false
    end

    def visit(node : Call)
      call_vars = {} of String => Value

      if obj = node.obj
        obj.accept self
        obj_value = @value
        call_scope = obj_value.type
        call_vars["self"] = obj_value
      else
        if @scope
          call_scope = @scope
          call_vars["self"] = @vars["self"]
        else
          call_scope = @mod
        end
      end

      values = node.args.map do |arg|
        arg.accept self
        @value
      end

      types = [] of Type
      values.each do |value|
        types << value.type
      end

      matches = call_scope.lookup_matches(node.name, types, !!node.block)
      case matches.length
      when 0
        if call_scope.metaclass? && node.name == "new"
          instance_type = call_scope.instance_type
          initialize_matches = instance_type.lookup_matches("initialize", types, !!node.block)
          if initialize_matches.length == 0 && values.length == 0
            if instance_type.is_a?(GenericClassType)
              node.raise "can't create instance of generic class #{instance_type} without specifying its type vars"
            end
            @value = ClassValue.new(@mod, instance_type)
            return false
          elsif initialize_matches.length == 1
            matches = Call.define_new_with_initialize(call_scope, types, initialize_matches)
            @value = execute_call(matches.first, call_scope, call_vars, values, node)
            return false
          end
        end

        # This is just so that we can reuse code from the call
        error_call = node.clone
        error_call.mod = @mod
        error_call.args.zip(types) { |arg, type| arg.set_type(type) }

        error_call.raise_matches_not_found(call_scope, node.name)
      when 1
        match = matches.first

        # if node.block && (block_arg = match.def.block_arg) && (yields = match.def.yields) && yields > 0
        #   node.block.not_nil!.accept self
        #   puts @parent_interpreter.not_nil!.value
        # end

        @value = execute_call(match, call_scope, call_vars, values, node)
      else
        node.raise "Bug: more than one match found for #{call_scope}##{node.name}"
      end

      false
    end

    def execute_call(match, call_scope, call_vars, values, call)
      target_def = match.def
      if target_def.is_a?(External)
        call.raise "can't interpret external calls"
      end

      target_def.args.zip(values) do |arg, value|
        call_vars[arg.name] = value
      end

      interpreter = Interpreter.new(@mod, call_scope, call_vars, target_def, call, self, match.free_vars)
      target_def.body.accept interpreter
      interpreter.value
    end

    def visit(node : Yield)
      block = @call.not_nil!.block.not_nil!
      parent_interpreter = @parent_interpreter.not_nil!

      overwritten_vars = {} of String => Value?

      block.args.each_with_index do |arg, i|
        overwritten_vars[arg.name] = parent_interpreter.vars[arg.name]?

        exp = node.exps[i]?
        if exp
          exp.accept self
          parent_interpreter.vars[arg.name] = @value
        else
          parent_interpreter.vars[arg.name] = nil_value
        end
      end

      block.accept parent_interpreter

      overwritten_vars.each do |name, value|
        if value
          parent_interpreter.vars[name] = value
        else
          parent_interpreter.vars.delete name
        end
      end

      @value = parent_interpreter.value

      false
    end

    def visit(node : Primitive)
      case node.name
      when :binary
        visit_binary node
      when :cast
        visit_cast node
      when :allocate
        visit_allocate node
      when :object_id
        visit_object_id node
      when :pointer_malloc
        visit_pointer_malloc node
      when :pointer_set
        visit_pointer_set node
      when :pointer_get
        visit_pointer_get node
      when :pointer_add
        visit_pointer_add node
      when :pointer_address
        visit_pointer_address node
      when :pointer_new
        visit_pointer_new node
      when :pointer_cast
        visit_pointer_cast node
      else
        node.raise "Bug: unhandled primitive in interpret: #{node.name}"
      end
    end

    def visit_binary(node)
      case current_def.name
      when "+" then visit_number_arithmetic(node) { |a, b| a + b }
      when "-" then visit_number_arithmetic(node) { |a, b| a - b }
      when "*" then visit_number_arithmetic(node) { |a, b| a * b }
      when "/" then visit_number_arithmetic(node) { |a, b| a / b }
      when "%" then visit_int_arithmetic(node) { |a, b| a % b }
      when "<<" then visit_int_arithmetic(node) { |a, b| a << b }
      when ">>" then visit_int_arithmetic(node) { |a, b| a >> b }
      when "|" then visit_int_arithmetic(node) { |a, b| a | b }
      when "&" then visit_int_arithmetic(node) { |a, b| a & b }
      when "^" then visit_int_arithmetic(node) { |a, b| a ^ b }
      when ">" then visit_number_cmp(node) { |a, b| a > b }
      when ">=" then visit_number_cmp(node) { |a, b| a >= b }
      when "<" then visit_number_cmp(node) { |a, b| a < b }
      when "<=" then visit_number_cmp(node) { |a, b| a <= b }
      when "==" then visit_cmp(node) { |a, b| a == b }
      when "!=" then visit_cmp(node) { |a, b| a != b }
      else
        raise "Bug: unknown binary operator #{current_def.name}"
      end
    end

    def visit_number_arithmetic(node)
      expand_binary_number(node) do |v1, v1_value, v2, v2_value|
        res_type = v1.type.integer? && v2.type.float? ? v2.type : v1.type
        @value = PrimitiveValue.new(res_type, yield(v1_value, v2_value))
      end
    end

    def visit_int_arithmetic(node)
      expand_binary_int(node) do |v1, v1_value, v2, v2_value|
        @value = PrimitiveValue.new(v1.type, yield(v1_value, v2_value))
      end
    end

    def visit_number_cmp(node)
      expand_binary_number(node) do |v1, v1_value, v2, v2_value|
        @value = PrimitiveValue.new(@mod.bool, yield(v1_value, v2_value))
      end
    end

    def expand_binary_number(node)
      v1 = @vars["self"] as PrimitiveValue
      v2 = @vars["other"] as PrimitiveValue

      v1_value = v1.value as Number
      v2_value = v2.value as Number

      yield v1, v1_value, v2, v2_value
    end

    def expand_binary_int(node)
      v1 = @vars["self"] as PrimitiveValue
      v2 = @vars["other"] as PrimitiveValue

      v1_value = v1.value as Int
      v2_value = v2.value as Int

      yield v1, v1_value, v2, v2_value
    end

    def visit_cmp(node)
      v1 = @vars["self"] as PrimitiveValue
      v2 = @vars["other"] as PrimitiveValue

      @value = PrimitiveValue.new(@mod.bool, yield(v1.value, v2.value))
    end

    def visit_cast(node)
      val = @vars["self"] as PrimitiveValue

      value = val.value

      case current_def.name
      when "to_i"
        assert_responds_to value, :to_i
        @value = PrimitiveValue.new(@mod.int32, value.to_i)
      when "to_i8"
        assert_responds_to value, :to_i8
        @value = PrimitiveValue.new(@mod.int8, value.to_i8)
      when "to_i16"
        assert_responds_to value, :to_i16
        @value = PrimitiveValue.new(@mod.int16, value.to_i16)
      when "to_i32"
        assert_responds_to value, :to_i32
        @value = PrimitiveValue.new(@mod.int32, value.to_i32)
      when "to_i64"
        assert_responds_to value, :to_i64
        @value = PrimitiveValue.new(@mod.int64, value.to_i64)
      when "to_u"
        assert_responds_to value, :to_u
        @value = PrimitiveValue.new(@mod.uint32, value.to_u)
      when "to_u8"
        assert_responds_to value, :to_u8
        @value = PrimitiveValue.new(@mod.uint8, value.to_u8)
      when "to_u16"
        assert_responds_to value, :to_u16
        @value = PrimitiveValue.new(@mod.uint16, value.to_u16)
      when "to_u32"
        assert_responds_to value, :to_u32
        @value = PrimitiveValue.new(@mod.uint32, value.to_u32)
      when "to_u64"
        assert_responds_to value, :to_u64
        @value = PrimitiveValue.new(@mod.uint64, value.to_u64)
      when "to_f"
        assert_responds_to value, :to_f
        @value = PrimitiveValue.new(@mod.float64, value.to_f)
      when "to_f32"
        assert_responds_to value, :to_f32
        @value = PrimitiveValue.new(@mod.float64, value.to_f32)
      when "to_f64"
        assert_responds_to value, :to_f64
        @value = PrimitiveValue.new(@mod.float64, value.to_f64)
      when "chr"
        assert_responds_to value, :chr
        @value = PrimitiveValue.new(@mod.char, value.chr)
      when "ord"
        assert_responds_to value, :ord
        @value = PrimitiveValue.new(@mod.int32, value.ord)
      else
        raise "Bug: unkown cast operator #{current_def.name}"
      end
    end

    def visit_allocate(node)
      instance_type = process_allocate(node)
      @value = ClassValue.new(@mod, instance_type)
    end

    def visit_object_id(node)
      @value = PrimitiveValue.new(@mod.uint64, self_value.object_id)
    end

    def visit_pointer_malloc(node)
      scope = @scope.not_nil!.instance_type as PointerInstanceType

      size = @vars["size"] as PrimitiveValue
      size_value = size.value as UInt64

      size_value *= size_of(scope)

      @value = PointerValue.new(scope, Pointer(Int8).malloc(size_value))
    end

    def visit_pointer_set(node)
      self_value = @vars["self"] as PointerValue

      value = @vars["value"]

      self_value.value = value

      @value = value
    end

    def visit_pointer_get(node)
      self_value = @vars["self"] as PointerValue

      @value = self_value.value
    end

    def visit_pointer_add(node)
      self_value = @vars["self"] as PointerValue
      offset = @vars["offset"] as PrimitiveValue
      offset_value  = offset.value as Int64
      type = self_value.type as PointerInstanceType
      size = size_of(type.element_type)
      @value = PointerValue.new(self_value.type, self_value.data + (size * offset_value))
    end

    def visit_pointer_address(node)
      self_value = @vars["self"] as PointerValue
      @value = PrimitiveValue.new(@mod.uint64, self_value.data.address)
    end

    def visit_pointer_new(node)
      scope = @scope.not_nil!.instance_type as PointerInstanceType

      address = @vars["address"] as PrimitiveValue
      address_value = address.value as UInt64

      @value = PointerValue.new(scope, Pointer(Int8).new(address_value))
    end

    def visit_pointer_cast(node)
      self_value = @vars["self"] as PointerValue

      type = @vars["type"]
      type_type = type.type.instance_type

      if type_type.class?
        @value = PointerValue.new(type_type, self_value.data)
      else
        @value = PointerValue.new(@mod.pointer_of(type_type), self_value.data)
      end
    end

    def visit(node : Path)
      type = resolve_ident(node)
      case type
      when ConstValue
        @value = type.value
      when Type
        ident_type = type.remove_alias_if_simple.metaclass
        node.type = ident_type
        @value = MetaclassValue.new(ident_type)
      # when ASTNode
      #   node.syntax_replacement = type
      #   node.bind_to type
      end
    end

    def nil_value
      @nil_value ||= PrimitiveValue.new(@mod.nil, nil)
    end

    def self_value
      @vars["self"] as ClassValue
    end

    def size_of(type)
      # TODO
      8
    end

    abstract class Value
      getter type

      def initialize(@type)
      end
    end

    class PrimitiveValue < Value
      getter value

      def initialize(type, @value)
        super(type)
      end

      def truthy?
        if type.nil_type?
          false
        elsif type.bool_type?
          value == true
        else
          true
        end
      end

      def ==(other : PrimitiveValue)
        value == other.value
      end

      def to_s
        "#{@value.inspect} :: #{@type}"
      end
    end

    class ClassValue < Value
      getter vars

      def initialize(@mod, type, @vars = {} of String => Value)
        super(type)
      end

      def [](name)
        @vars[name] ||= PrimitiveValue.new(@mod.nil, nil)
      end

      def []=(name, value)
        @vars[name] = value
      end

      def truthy?
        true
      end

      def to_s
        "#{@vars} :: #{@type} @ #{object_id}"
      end
    end

    class PointerValue < Value
      getter data

      def initialize(type, @data)
        super(type)
      end

      def value=(value : PrimitiveValue)
        type = @type as PointerInstanceType

        value_value = value.value

        case value_value
        when Nil
          (@data as Nil*).value = value_value
        when Bool
          (@data as Bool*).value = value_value
        when Char
          (@data as Char*).value = value_value
        when Int8
          (@data as Int8*).value = value_value
        when UInt8
          (@data as UInt8*).value = value_value
        when Int16
          (@data as Int16*).value = value_value
        when UInt16
          (@data as UInt16*).value = value_value
        when Int32
          (@data as Int32*).value = value_value
        when UInt32
          (@data as UInt32*).value = value_value
        when Int64
          (@data as Int64*).value = value_value
        when UInt64
          (@data as UInt64*).value = value_value
        when Float32
          (@data as Float32*).value = value_value
        when Float64
          (@data as Float64*).value = value_value
        end
      end

      def value=(value)
        # TODO
      end

      def value
        type = @type as PointerInstanceType
        element_type = type.element_type

        if element_type.is_a?(PrimitiveType)
          size = element_type.bytes
          case size
          when 1
            PrimitiveValue.new(element_type, (@data as Int8*).value)
          when 2
            PrimitiveValue.new(element_type, (@data as Int16*).value)
          when 4
            PrimitiveValue.new(element_type, (@data as Int32*).value)
          when 8
            PrimitiveValue.new(element_type, (@data as Int64*).value)
          else
            raise "Unhandled size: #{size}"
          end
        else
          raise "Not yet implemented for #{element_type}"
        end
      end

      def truthy?
        !@data.nil?
      end

      def to_s
        "* :: #{type} @ #{@data.address}"
      end
    end

    class MetaclassValue < Value
      def truthy?
        true
      end

      def to_s
        @type.to_s
      end
    end

    class ConstValue < ::Crystal::ContainedType
      getter value

      def initialize(program, container, @value)
        super(program, container)
      end
    end
  end
end
