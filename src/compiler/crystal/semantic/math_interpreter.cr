require "./semantic_visitor"

# Interprets math expressions like 1 + 2 for enum values and
# constant values that are being used for the N of a StaticArray.
struct Crystal::MathInterpreter
  def initialize(@path_lookup : Type, @visitor : SemanticVisitor? = nil)
  end

  def interpret(node : NumberLiteral, target_type = nil)
    case node.kind
    when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64, :i64
      target_kind = target_type.try(&.kind) || node.kind
      case target_kind
      when :i8  then node.value.to_i8? || node.raise "Invalid Int8: #{node.value}"
      when :u8  then node.value.to_u8? || node.raise "Invalid UInt8: #{node.value}"
      when :i16 then node.value.to_i16? || node.raise "Invalid Int16: #{node.value}"
      when :u16 then node.value.to_u16? || node.raise "Invalid UInt16: #{node.value}"
      when :i32 then node.value.to_i32? || node.raise "Invalid Int32: #{node.value}"
      when :u32 then node.value.to_u32? || node.raise "Invalid UInt32: #{node.value}"
      when :i64 then node.value.to_i64? || node.raise "Invalid Int64: #{node.value}"
      when :u64 then node.value.to_u64? || node.raise "Invalid UInt64: #{node.value}"
      else
        node.raise "Enum type must be an integer, not #{target_kind}"
      end
    else
      node.raise "Constant value must be an integer, not #{node.kind}"
    end
  end

  def interpret(node : Call, target_type = nil)
    obj = node.obj
    if obj
      if obj.is_a?(Path)
        value = interpret_call_macro?(node, target_type)
        return value if value
      end

      case node.args.size
      when 0
        left = interpret(obj, target_type)

        case node.name
        when "+" then +left
        when "-"
          case left
          when Int8  then -left
          when Int16 then -left
          when Int32 then -left
          when Int64 then -left
          else
            interpret_call_macro(node, target_type)
          end
        when "~" then ~left
        else
          interpret_call_macro(node, target_type)
        end
      when 1
        left = interpret(obj, target_type)
        right = interpret(node.args.first, target_type)

        case node.name
        when "+"  then left + right
        when "-"  then left - right
        when "*"  then left * right
        when "/"  then left / right
        when "&"  then left & right
        when "|"  then left | right
        when "<<" then left << right
        when ">>" then left >> right
        when "%"  then left % right
        else
          interpret_call_macro(node, target_type)
        end
      else
        node.raise "Invalid constant value"
      end
    else
      interpret_call_macro(node, target_type)
    end
  end

  def interpret_call_macro(node : Call, target_type = nil)
    interpret_call_macro?(node, target_type) ||
      node.raise("Invalid constant value")
  end

  def interpret_call_macro?(node : Call, target_type = nil)
    visitor = @visitor
    return unless visitor

    if node.global?
      node.scope = visitor.program
    else
      node.scope = visitor.scope? || visitor.current_type.metaclass
    end

    if visitor.expand_macro(node, raise_on_missing_const: false, first_pass: true)
      return interpret(node.expanded.not_nil!, target_type)
    end

    nil
  end

  def interpret(node : Path, target_type = nil)
    type = @path_lookup.lookup_type(node, allow_typeof: false)
    case type
    when Const
      interpret(type.value, target_type)
    else
      node.raise "Invalid constant value"
    end
  end

  def interpret(node : Expressions, target_type = nil)
    if node.expressions.size == 1
      interpret(node.expressions.first)
    else
      node.raise "Invalid constant value"
    end
  end

  def interpret(node : ASTNode, target_type = nil)
    node.raise "Invalid constant value"
  end
end
