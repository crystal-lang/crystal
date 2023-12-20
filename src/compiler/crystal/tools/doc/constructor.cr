struct Crystal::ConstructorAnnotation
  getter? constructor : Bool = true

  def initialize(@constructor : Bool = true); end

  def self.from(ann : Annotation)
    args = ann.args
    named_args = ann.named_args

    if named_args
      ann.raise "too many named arguments (given #{named_args.size}, expected maximum 0)"
    end

    is_constructor = true
    count = 0

    args.each do |arg|
      case count
      when 0
        arg.raise "first argument must be a Bool" unless arg.is_a?(BoolLiteral)
        is_constructor = arg.value
      else
        ann.wrong_number_of "constructor annotation arguments", args.size, "1"
      end

      count += 1
    end

    new is_constructor
  end
end
