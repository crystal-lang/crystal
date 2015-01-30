module JSON::Any
  def self.new(pull : JSON::PullParser)
    case pull.kind
    when :null
      pull.read_null
    when :bool
      pull.read_bool
    when :int
      pull.read_int
    when :float
      pull.read_float
    when :string
      pull.read_string
    when :begin_array
      ary = [] of JSON::Type
      pull.read_array do
        ary << new pull
      end
      ary
    when :begin_object
      hash = {} of String => JSON::Type
      pull.read_object do |key|
        hash[key] = new pull
      end
      hash
    else
      raise "Unknown pull kind: #{pull.kind}"
    end
  end
end
