require "./ast"
require "./visitor"

# This computes the end_location of a given ASTNode
# this information might be calculated from the parser
# directly. Meanwhile, this is an aproximation.
module Crystal
  class ASTNode
    def end_location
      if location
        @end_location ||= build_end_location
        @end_location
      else
        nil
      end
    end

    def build_end_location
      res = location.not_nil!

      location_child_nodes do |node|
        if node.is_a?(Array)
          if n = node.last?
            if node_end = n.end_location
              res = Math.max(res, node_end)
            end
          end
        elsif node.is_a?(ASTNode)
          if node_end = node.end_location
            res = Math.max(res, node_end)
          end
        end
      end

      res
    end

    def location_child_nodes
      yield nil
    end
  end

  class Call
    def build_end_location
      if loc = location
        block.try do |b|
          return b.end_location
        end

        if args.empty?
          Location.new(loc.line_number, name_column_number + name_length, loc.filename)
        else
          args.last.end_location
        end
      else
        nil
      end
    end
  end

  class Expressions
    def location
      res = super
      if res.nil? && !empty?
        res = self[0].location
      end

      res
    end

    def location_child_nodes
      unless empty?
        yield last
      end
    end
  end

  class Def
    def location_child_nodes
      yield @body
    end
  end

  class While
    def location_child_nodes
      yield @body
    end
  end

  class Rescue < ASTNode
    def end_location
      # Recues does not have starting location
      @body.end_location
    end
  end

  class If
    def location_child_nodes
      yield @cond
      yield @then
      yield @else
    end
  end

  class ExceptionHandler
    def location_child_nodes
      yield @body
      yield @rescues
      yield @else
      yield @ensure
    end
  end

  class Block
    def location
      super || @args.first?.try(&.location) || @body.try(&.location)
    end

    def location_child_nodes
      yield @args
      yield @body
    end
  end

  class Assign < ASTNode
    def location_child_nodes
      yield @value
    end
  end
end
