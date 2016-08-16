require "./semantic_visitor"

class Crystal::SemanticVisitor
  def interpret_enum_value(node : NumberLiteral, target_type = nil)
    case node.kind
    when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64, :i64
      target_kind = target_type.try(&.kind) || node.kind
      case target_kind
      when :i8  then node.value.to_i8? || node.raise "invalid Int8: #{node.value}"
      when :u8  then node.value.to_u8? || node.raise "invalid UInt8: #{node.value}"
      when :i16 then node.value.to_i16? || node.raise "invalid Int16: #{node.value}"
      when :u16 then node.value.to_u16? || node.raise "invalid UInt16: #{node.value}"
      when :i32 then node.value.to_i32? || node.raise "invalid Int32: #{node.value}"
      when :u32 then node.value.to_u32? || node.raise "invalid UInt32: #{node.value}"
      when :i64 then node.value.to_i64? || node.raise "invalid Int64: #{node.value}"
      when :u64 then node.value.to_u64? || node.raise "invalid UInt64: #{node.value}"
      else
        node.raise "enum type must be an integer, not #{target_kind}"
      end
    else
      node.raise "constant value must be an integer, not #{node.kind}"
    end
  end

  def interpret_enum_value(node : Call, target_type = nil)
    obj = node.obj
    if obj
      if obj.is_a?(Path)
        value = interpret_enum_value_call_macro?(node, target_type)
        return value if value
      end

      case node.args.size
      when 0
        left = interpret_enum_value(obj, target_type)

        case node.name
        when "+" then +left
        when "-"
          case left
          when Int8  then -left
          when Int16 then -left
          when Int32 then -left
          when Int64 then -left
          else
            interpret_enum_value_call_macro(node, target_type)
          end
        when "~" then ~left
        else
          interpret_enum_value_call_macro(node, target_type)
        end
      when 1
        left = interpret_enum_value(obj, target_type)
        right = interpret_enum_value(node.args.first, target_type)

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
          interpret_enum_value_call_macro(node, target_type)
        end
      else
        node.raise "invalid constant value"
      end
    else
      interpret_enum_value_call_macro(node, target_type)
    end
  end

  def interpret_enum_value_call_macro(node : Call, target_type = nil)
    interpret_enum_value_call_macro?(node, target_type) ||
      node.raise("invalid constant value")
  end

  def interpret_enum_value_call_macro?(node : Call, target_type = nil)
    if node.global?
      node.scope = @program
    else
      node.scope = @scope || current_type.metaclass
    end

    if expand_macro(node, raise_on_missing_const: false, first_pass: true)
      return interpret_enum_value(node.expanded.not_nil!, target_type)
    end

    nil
  end

  def interpret_enum_value(node : Path, target_type = nil)
    type = lookup_type(node)
    case type
    when Const
      interpret_enum_value(type.value, target_type)
    else
      node.raise "invalid constant value"
    end
  end

  def interpret_enum_value(node : Expressions, target_type = nil)
    if node.expressions.size == 1
      interpret_enum_value(node.expressions.first)
    else
      node.raise "invalid constant value"
    end
  end

  def interpret_enum_value(node : ASTNode, target_type = nil)
    node.raise "invalid constant value"
  end
end
