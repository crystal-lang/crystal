class JSON::Token
  property type : Symbol
  property string_value : String
  property int_value : Int64
  property float_value : Float64
  property line_number : Int32
  property column_number : Int32
  property raw_value : String

  def initialize
    @type = :EOF
    @line_number = 0
    @column_number = 0
    @string_value = ""
    @int_value = 0_i64
    @float_value = 0.0
    @raw_value = ""
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
