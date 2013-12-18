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

    def initialize(@mod, @scope = nil, @vars = {} of String => Value, @current_def = nil, @free_vars = nil)
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
      @value = PrimitiveValue.new(mod.char, node.value[0])
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
      else
        raise "Assign not implemented yet: #{node.to_s_node}"
      end

      false
    end

    def visit(node : Var)
      @value = @vars[node.name]
    end

    def visit(node : InstanceVar)
      scope = @vars["self"]
      assert_type scope, ClassValue
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

    def end_visit(node : IdentUnion)
      process_ident_union(node)
      @value = MetaclassValue.new(node.type)
    end

    def end_visit(node : Hierarchy)
      process_hierarchy(node)
      @value = MetaclassValue.new(node.type)
    end

    def end_visit(node : NewGenericClass)
      process_new_generic_class(node)
      @value = MetaclassValue.new(node.type)
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
            @value = execute_call(matches.first, call_scope, call_vars, values)
            return false
          end
        end

        node.raise "undefined method #{node.name} for #{call_scope}"
      when 1
        @value = execute_call(matches.first, call_scope, call_vars, values)
      else
        node.raise "Bug: more than one match found for #{call_scope}##{node.name}"
      end

      false
    end

    def execute_call(match, call_scope, call_vars, values)
      target_def = match.def
      target_def.args.zip(values) do |arg, value|
        call_vars[arg.name] = value
      end

      interpreter = Interpreter.new(@mod, call_scope, call_vars, target_def, match.free_vars)
      target_def.body.accept interpreter
      interpreter.value
    end

    def visit(node : Primitive)
      case node.name
      when :binary
        visit_binary node
      when :allocate
        visit_allocate node
      when :object_id
        visit_object_id node
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
      v1 = @vars["self"]
      v2 = @vars["other"]

      assert_type v1, PrimitiveValue
      assert_type v2, PrimitiveValue

      v1_value = v1.value
      v2_value = v2.value

      assert_type v1_value, Number
      assert_type v2_value, Number

      yield v1, v1_value, v2, v2_value
    end

    def expand_binary_int(node)
      v1 = @vars["self"]
      v2 = @vars["other"]

      assert_type v1, PrimitiveValue
      assert_type v2, PrimitiveValue

      v1_value = v1.value
      v2_value = v2.value

      assert_type v1_value, Int
      assert_type v2_value, Int

      yield v1, v1_value, v2, v2_value
    end

    def visit_cmp(node)
      v1 = @vars["self"]
      v2 = @vars["other"]

      assert_type v1, PrimitiveValue
      assert_type v2, PrimitiveValue

      @value = PrimitiveValue.new(@mod.bool, yield(v1.value, v2.value))
    end

    def visit_allocate(node)
      instance_type = process_allocate(node)
      @value = ClassValue.new(@mod, instance_type)
    end

    def visit_object_id(node)
      @value = PrimitiveValue.new(@mod.uint64, self_value.object_id)
    end

    def visit(node : Ident)
      type = resolve_ident(node)
      case type
      # when Const
      #   unless type.value.type?
      #     old_types, old_scope, old_vars = @types, @scope, @vars
      #     @types, @scope, @vars = type.scope_types, type.scope, ({} of String => Var)
      #     type.value.accept self
      #     @types, @scope, @vars = old_types, old_scope, old_vars
      #   end
      #   node.target_const = type
      #   node.bind_to type.value
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
      value = @vars["self"]
      assert_type value, ClassValue
      value
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

    class MetaclassValue < Value
      def truthy?
        true
      end

      def to_s
        @type.to_s
      end
    end
  end
end
