require "./semantic_visitor"

# Interprets math expressions like 1 + 2 for enum values and
# constant values that are being used for the N of a StaticArray.
struct Crystal::MathInterpreter
  def initialize(@path_lookup : Type, @visitor : SemanticVisitor? = nil, @target_type : IntegerType? = nil)
  end

  def interpret(node : NumberLiteral)
    case node.kind
    when .signed_int?, .unsigned_int?
      target_kind = @target_type.try(&.kind) || node.kind
      case target_kind
      when .i8?   then node.value.to_i8? || node.raise "invalid Int8: #{node.value}"
      when .u8?   then node.value.to_u8? || node.raise "invalid UInt8: #{node.value}"
      when .i16?  then node.value.to_i16? || node.raise "invalid Int16: #{node.value}"
      when .u16?  then node.value.to_u16? || node.raise "invalid UInt16: #{node.value}"
      when .i32?  then node.value.to_i32? || node.raise "invalid Int32: #{node.value}"
      when .u32?  then node.value.to_u32? || node.raise "invalid UInt32: #{node.value}"
      when .i64?  then node.value.to_i64? || node.raise "invalid Int64: #{node.value}"
      when .u64?  then node.value.to_u64? || node.raise "invalid UInt64: #{node.value}"
      when .i128? then node.value.to_i128? || node.raise "invalid Int128: #{node.value}"
      when .u128? then node.value.to_u128? || node.raise "invalid UInt128: #{node.value}"
      else
        node.raise "enum type must be an integer, not #{target_kind}"
      end
    else
      node.raise "constant value must be an integer, not #{node.kind}"
    end
  end

  def interpret(node : Call)
    obj = node.obj
    if obj
      if obj.is_a?(Path)
        value = interpret_call_macro?(node)
        return value if value
      end

      case node.args.size
      when 0
        left = interpret(obj)

        case node.name
        when "+" then +left
        when "-"
          case left
          when Int8   then -left
          when Int16  then -left
          when Int32  then -left
          when Int64  then -left
          when Int128 then -left
          else
            interpret_call_macro(node)
          end
        when "~" then ~left
        else
          interpret_call_macro(node)
        end
      when 1
        left = interpret(obj)
        right = interpret(node.args.first)

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
        node.raise "invalid constant value"
      end
    else
      interpret_call_macro(node)
    end
  end

  def interpret_call_macro(node : Call)
    interpret_call_macro?(node) ||
      node.raise("invalid constant value")
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
      node.raise "invalid constant value"
    end
  end

  def interpret(node : Expressions)
    if node.expressions.size == 1
      interpret(node.expressions.first)
    else
      node.raise "invalid constant value"
    end
  end

  def interpret(node : ASTNode)
    node.raise "invalid constant value"
  end
end
