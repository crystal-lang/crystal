require "./semantic_visitor"

# Interprets math expressions like 1 + 2 for enum values and
# constant values that are being used for the N of a StaticArray.
struct Crystal::MathInterpreter
  def initialize(@path_lookup : Type, @visitor : SemanticVisitor? = nil, @target_type : IntegerType? = nil)
  end

  private def make_error(node, message)
    Crystal::TypeException.for_node(node, message)
  end

  def interpret(node : NumberLiteral)
    case node.kind
    when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64
      target_kind = @target_type.try(&.kind) || node.kind
      case target_kind
      when :i8  then node.value.to_i8? || make_error node, "invalid Int8: #{node.value}"
      when :u8  then node.value.to_u8? || make_error node, "invalid UInt8: #{node.value}"
      when :i16 then node.value.to_i16? || make_error node, "invalid Int16: #{node.value}"
      when :u16 then node.value.to_u16? || make_error node, "invalid UInt16: #{node.value}"
      when :i32 then node.value.to_i32? || make_error node, "invalid Int32: #{node.value}"
      when :u32 then node.value.to_u32? || make_error node, "invalid UInt32: #{node.value}"
      when :i64 then node.value.to_i64? || make_error node, "invalid Int64: #{node.value}"
      when :u64 then node.value.to_u64? || make_error node, "invalid UInt64: #{node.value}"
      else
        make_error node, "enum type must be an integer, not #{target_kind}"
      end
    else
      make_error node, "constant value must be an integer, not #{node.kind}"
    end
  end

  def interpret(node : Call)
    obj = node.obj
    if obj
      if obj.is_a?(Path)
        value = interpret_call_macro?(node)
        return value unless value.is_a?(Nil | Exception)
      end

      case node.args.size
      when 0
        left = interpret(obj)
        return left if left.is_a?(Exception)

        case node.name
        when "+" then +left
        when "-"
          case left
          when Int8  then -left
          when Int16 then -left
          when Int32 then -left
          when Int64 then -left
          else
            interpret_call_macro(node)
          end
        when "~" then ~left
        else
          interpret_call_macro(node)
        end
      when 1
        left = interpret(obj)
        return left if left.is_a?(Exception)
        right = interpret(node.args.first)
        return right if right.is_a?(Exception)

        case node.name
        when "+"  then left + right
        when "-"  then left - right
        when "*"  then left * right
        when "&+" then left &+ right
        when "&-" then left &- right
        when "&*" then left &* right
          # MathInterpreter only works with Integer and left / right : Float
          # when "/"  then left / right
        when "//" then left // right
        when "&"  then left & right
        when "|"  then left | right
        when "<<" then left << right
        when ">>" then left >> right
        when "%"  then left % right
        else
          interpret_call_macro(node)
        end
      else
        make_error node, "invalid constant value"
      end
    else
      interpret_call_macro(node)
    end
  end

  def interpret_call_macro(node : Call)
    interpret_call_macro?(node) ||
      make_error node, "invalid constant value"
  end

  def interpret_call_macro?(node : Call)
    visitor = @visitor
    return unless visitor

    if node.global?
      node.scope = visitor.program
    else
      node.scope = visitor.scope? || visitor.current_type.metaclass
    end

    if visitor.expand_macro(node, raise_on_missing_const: false, first_pass: true)
      return interpret(node.expanded.not_nil!)
    end

    nil
  end

  def interpret(node : Path)
    type = @path_lookup.lookup_type_var(node)
    case type
    when Const
      interpret(type.value)
    else
      make_error node, "invalid constant value"
    end
  end

  def interpret(node : Expressions)
    if node.expressions.size == 1
      interpret(node.expressions.first)
    else
      make_error node, "invalid constant value"
    end
  end

  def interpret(node : ASTNode)
    make_error node, "invalid constant value"
  end

  def interpret(node : ASTNode)
    result = interpret(node)
    return yield result if result.is_a?(Exception)
    result
  end
end
