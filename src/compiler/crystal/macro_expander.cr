module Crystal
  class MacroExpander
    def initialize(@mod, @macro)
    end

    def expand(node)
      return String.build do |str|
        @macro.body.each do |exp|
          case exp
          when StringLiteral
            str << exp.value
          when Var
            index = @macro.args.index { |arg| arg.name == exp.name }
            if index
              str << node.args[index].to_s_for_macro
            else
              exp.raise "undefined macro variable '#{exp.name}'"
            end
          end
        end
      end
    end
  end
end
