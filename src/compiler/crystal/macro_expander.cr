module Crystal
  class MacroExpander
    def initialize(@mod, @untyped_def)
    end

    def expand(node)
      body = @untyped_def.body

      # A simple case: when the macro is just a string interpolation with variables,
      # we do it without a JIT
      case body
      when StringLiteral
        return body.value
      when StringInterpolation
        if body.expressions.all? { |exp| exp.is_a?(StringLiteral) || exp.is_a?(Var) }
          return String.build do |str|
            body.expressions.each do |exp|
              case exp
              when StringLiteral
                str << exp.value
              when Var
                index = @untyped_def.args.index { |arg| arg.name == exp.name }.not_nil!
                str << node.args[index].to_s
              end
            end
          end
        end
      end

      node.raise "Macros only support strings or string interpolations with variables (for now)"
    end
  end
end
