module Crystal
  struct ExperimentalAnnotation
    getter message : String?

    def initialize(@message = nil)
    end

    def self.from(ann : Annotation)
      args = ann.args
      named_args = ann.named_args

      if named_args
        ann.raise "too many named arguments (given #{named_args.size}, expected maximum 0)"
      end

      message = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          arg.raise "first argument must be a String" unless arg.is_a?(StringLiteral)
          message = arg.value
        else
          ann.wrong_number_of "experimental annotation arguments", args.size, "1"
        end

        count += 1
      end

      new(message)
    end
  end
end
