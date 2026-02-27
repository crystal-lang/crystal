module Crystal
  struct ThreadLocalAnnotation
    getter unsafe : Bool = false

    def initialize(*, @unsafe = false)
    end

    def self.from(ann : Annotation)
      args = ann.args
      named_args = ann.named_args

      if !args.empty?
        ann.raise "too many positional arguments (given #{args.size}, expected maximum 0)"
      end

      unsafe = false

      if named_args
        named_args.each do |arg|
          case arg.name
          when "unsafe"
            value = arg.value
            arg.raise "argument unsafe must be a Bool" unless value.is_a?(BoolLiteral)
            unsafe = value.value
          else
            arg.raise "unexpected argument: #{arg.name}"
          end
        end
      end

      new(unsafe: unsafe)
    end
  end
end
