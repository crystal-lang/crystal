class JSON::Token
  property :type
  property :string_value
  property :int_value
  property :float_value
  property :line_number
  property :column_number

  def initialize
    @type = :EOF
    @line_number = 0
    @column_number = 0
    @string_value = ""
    @int_value = 0_i64
    @float_value = 0.0
  end

  def to_s(io)
    case @type
    when :INT
      @int_value.to_s(io)
    when :FLOAT
      @float_value.to_s(io)
    when :STRING
      @string_value.to_s(io)
    else
      @type.to_s(io)
    end
  end
end
