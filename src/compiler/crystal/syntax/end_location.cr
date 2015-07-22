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
      location
    end
  end

  class Call
    def build_end_location
      if loc = location
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
    def build_end_location
      if empty?
        location
      else
        last.end_location
      end
    end
  end

  class Def
    def build_end_location
      body.end_location || location
    end
  end
end
