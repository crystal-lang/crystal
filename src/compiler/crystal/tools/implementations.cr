require "../syntax/ast"

module Crystal
  class ImplementationsVisitor < Visitor
    def initialize(@target_location)
    end

    def visit(node : Call)
      if contains_token_target(node)
        if target_defs = node.target_defs
          target_defs.each do |target_def|
            puts target_def.location
          end
        end
      else
        if contains_target(node)
          true
        end
      end
    end

    def visit(node : Expressions)
      true
    end

    def visit(node)
      contains_target(node)
    end

    def contains_target(node)
      if loc = node.location
        if loc.filename == @target_location.filename
          a = { loc.line_number, loc.column_number }
          b = { @target_location.line_number, @target_location.column_number }
          if a <= b
            end_loc = end_location(node).not_nil!
            c = { end_loc.line_number, end_loc.column_number }
            if b <= c
              return true
            end
          end
        end
      end

      false
    end

    def end_location(node : Expressions)
      if node.empty?
        nil
      else
        node.last.location
      end
    end

    def end_location(node : Def)
      end_location(node.body)
    end

    def end_location(node : Call)
      if loc = node.location
        delta = node.name_length

        if o = node.obj
          delta += o.name_length + 1
        end

        if node.args.empty?
          Location.new(loc.line_number, loc.column_number + delta, loc.filename)
        else
          end_location(node.args.last)
        end
      else
        nil
      end
    end

    def end_location(node)
      node.location
    end



    def contains_token_target(node : Call)
      if loc = node.location
        if loc.filename == @target_location.filename
          a = { loc.line_number, loc.column_number }
          b = { @target_location.line_number, @target_location.column_number }
          if a <= b
            end_loc = end_token_location(node).not_nil!
            c = { end_loc.line_number, end_loc.column_number }
            if b <= c
              return true
            end
          end
        end
      end

      false
    end

    def end_token_location(node : Call)
      if loc = node.location
        delta = node.name_length

        if o = node.obj
          delta += o.name_length + 1
        end

        Location.new(loc.line_number, loc.column_number + delta, loc.filename)
      else
        nil
      end
    end
  end
end
