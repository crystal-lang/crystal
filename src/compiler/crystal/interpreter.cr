require "ast"
require "visitor"

module Crystal
  class Interpreter < Visitor
    getter value
    getter mod
    getter! current_def

    def initialize(@mod, @scope = mod, @vars = {} of String => Value, @current_def = nil)
      @value = PrimitiveValue.new(@mod.nil, nil)
      @types = [@mod] of Type
    end

    def interpret(code)
      parser = Parser.new(code)
      nodes = parser.parse
      nodes = @mod.normalize nodes
      nodes.accept self
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
      else
        raise "Assign not implemented yet: #{node.to_s_node}"
      end

      false
    end

    def visit(node : Var)
      @value = @vars[node.name]
    end

    def visit(node : ClassDef)
      superclass = if node_superclass = node.superclass
                     lookup_ident_type node_superclass
                   else
                     mod.reference
                   end

      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_ident_type node.name
      end

      type = scope.types[name]?
      if type
        node.raise "#{name} is not a class, it's a #{type.type_desc}" unless type.is_a?(ClassType)
        if node.superclass && type.superclass != superclass
          node.raise "superclass mismatch for class #{type} (#{superclass} for #{type.superclass})"
        end
      else
        unless superclass.is_a?(NonGenericClassType)
          node_superclass.not_nil!.raise "#{superclass} is not a class, it's a #{superclass.type_desc}"
        end

        needs_force_add_subclass = true
        if type_vars = node.type_vars
          type = GenericClassType.new @mod, scope, name, superclass, type_vars, false
        else
          type = NonGenericClassType.new @mod, scope, name, superclass, false
        end
        type.abstract = node.abstract
        scope.types[name] = type
      end

      @types.push type
      node.body.accept self
      @types.pop

      if needs_force_add_subclass
        raise "Bug" unless type.is_a?(InheritableClass)
        type.force_add_subclass
      end

      node.type = @mod.nil

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

    def visit(node : Def)
      if receiver = node.receiver
        # TODO: hack
        if receiver.is_a?(Var) && receiver.name == "self"
          target_type = current_type.metaclass
        else
          target_type = lookup_ident_type(receiver).metaclass
        end
      else
        target_type = current_type
      end

      target_type.add_def node

      node.set_type(@mod.nil)

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
        call_scope = @scope
      end

      values = node.args.map do |arg|
        arg.accept self
        @value
      end

      types = values.map &.type

      matches = call_scope.lookup_matches(node.name, types, !!node.block)
      case matches.length
      when 0
        node.raise "undefined method #{node.name} for #{call_scope}"
      when 1
        target_def = matches.first.def

        target_def.args.zip(values) do |arg, value|
          call_vars[arg.name] = value
        end

        interpreter = Interpreter.new(@mod, call_scope, call_vars, target_def)
        target_def.body.accept interpreter
        @value = interpreter.value
      else
        node.raise "Bug: more than one match found for #{call_scope}##{node.name}"
      end

      false
    end

    def visit(node : Primitive)
      case node.name
      when :binary
        visit_binary node
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

    def lookup_ident_type(node : Ident)
      target_type = resolve_ident(node)
      if target_type.is_a?(Type)
        target_type.remove_alias_if_simple
      else
        node.raise "#{node} must be a type here, not #{target_type}"
      end
    end

    def lookup_ident_type(node)
      raise "lookup_ident_type not implemented for #{node}"
    end

    def resolve_ident(node : Ident)
      free_vars = @free_vars
      if free_vars && !node.global && (type = free_vars[node.names.first]?)
        if node.names.length == 1
          target_type = type.not_nil!
        else
          target_type = type.not_nil!.lookup_type(node.names[1 .. -1])
        end
      elsif node.global
        target_type = mod.lookup_type node.names
      else
        target_type = (@scope || @types.last).lookup_type node
      end

      unless target_type
        node.raise "uninitialized constant #{node.to_s_node}"
      end

      target_type
    end

    def current_type
      @types.last
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
        "PrimitiveValue(#{@type}, #{@value.inspect})"
      end
    end

    class ClassValue < Value
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
        "ClassValue(#{@type}, #{@vars})"
      end
    end
  end
end
