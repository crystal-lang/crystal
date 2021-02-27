require "./semantic_visitor"

# Like Crystal::MathInterpreter but avoiding creating unions
# of different integer types to workaround
# https://github.com/crystal-lang/crystal/issues/10359
struct Crystal::TypedMathInterpreter(T)
  def initialize(@path_lookup : Type, @visitor : SemanticVisitor? = nil)
  end

  def interpret(node : NumberLiteral)
    case node.kind
    when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64
      begin
        T.new(node.value)
      rescue
        node.raise "invalid #{T}: #{node.value}"
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
