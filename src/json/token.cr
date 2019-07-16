class JSON::Token
  enum Kind
    Null
    False
    True
    Int
    Float
    String
    BeginArray
    EndArray
    BeginObject
    EndObject
    Colon
    Comma
    EOF
  end

  property kind : Kind
  property string_value : String
  property int_value : Int64
  property float_value : Float64
  property line_number : Int32
  property column_number : Int32
  property raw_value : String

  def initialize
    @kind = :EOF
    @line_number = 0
    @column_number = 0
    @string_value = ""
    @int_value = 0_i64
    @float_value = 0.0
    @raw_value = ""
  end

  @[Deprecated("Use JSON::Token#kind, which is an enum")]
  def type : Symbol
    case @kind
    when .null?
      :null
    when .false?
      :false
    when .true?
      :true
    when .int?
      :INT
    when .float?
      :FLOAT
    when .string?
      :STRING
    when .begin_array?
      :"["
    when .end_array?
      :"]"
    when .begin_object?
      :"{"
    when .end_object?
      :"}"
    when .colon?
      :":"
    when .comma?
      :","
    when .eof?
      :EOF
    else
      raise "Unknown token kind: #{@kind}"
    end
  end

  def to_s(io : IO) : Nil
    case @kind
    when .null?
      io << "null"
    when .false?
      io << "false"
    when .true?
      io << "true"
    when .int?
      raw_value.to_s(io)
    when .float?
      raw_value.to_s(io)
    when .string?
      string_value.to_s(io)
    when .begin_array?
      io << '['
    when .end_array?
      io << ']'
    when .begin_object?
      io << '{'
    when .end_object?
      io << '}'
    when .colon?
      io << ':'
    when .comma?
      io << ','
    when .eof?
      io << "<EOF>"
    else
      raise "Unknown token kind: #{@kind}"
    end
  end
end
