# This class allows you to consume JSON on demand, token by token.
class JSON::PullParser
  enum Kind
    Null
    Bool
    Int
    Float
    String
    BeginArray
    EndArray
    BeginObject
    EndObject
    EOF
  end

  private enum ObjectStackKind
    Object
    Array
  end

  getter kind : Kind
  getter bool_value : Bool
  getter int_value : Int64
  getter float_value : Float64
  getter string_value : String
  getter raw_value : String

  property max_nesting = 512

  def initialize(input)
    @lexer = Lexer.new input
    @kind = :EOF
    @bool_value = false
    @int_value = 0_i64
    @float_value = 0.0
    @string_value = ""
    @raw_value = ""
    @object_stack = [] of ObjectStackKind
    @skip_count = 0
    @location = {0, 0}

    next_token
    case token.kind
    when .null?
      @kind = :null
    when .false?
      @kind = :bool
      @bool_value = false
    when .true?
      @kind = :bool
      @bool_value = true
    when .int?
      @kind = :int
      @int_value = token.int_value
      @raw_value = token.raw_value
    when .float?
      @kind = :float
      @float_value = token.float_value
      @raw_value = token.raw_value
    when .string?
      @kind = :string
      @string_value = token.string_value
    when .begin_array?
      begin_array
    when .begin_object?
      begin_object
    else
      unexpected_token
    end
  end

  def read_begin_array
    expect_kind :begin_array
    read_next
  end

  def read_end_array
    expect_kind :end_array
    read_next
  end

  def read_array
    read_begin_array
    until kind.end_array?
      yield
    end
    read_end_array
  end

  def read_begin_object
    expect_kind :begin_object
    read_next
  end

  def read_end_object
    expect_kind :end_object
    read_next
  end

  def read_object_key
    read_string
  end

  def read_object
    read_begin_object
    until kind.end_object?
      key_location = location
      key = read_object_key
      yield key, key_location
    end
    read_end_object
  end

  def read_null
    expect_kind :null
    read_next
    nil
  end

  def read_bool
    expect_kind :bool
    @bool_value.tap { read_next }
  end

  def read_int
    expect_kind :int
    @int_value.tap { read_next }
  end

  def read_float
    case @kind
    when .int?
      @int_value.to_f.tap { read_next }
    when .float?
      @float_value.tap { read_next }
    else
      parse_exception "expecting int or float but was #{@kind}"
    end
  end

  def read_raw
    case @kind
    when .null?
      read_next
      "null"
    when .bool?
      @bool_value.to_s.tap { read_next }
    when .int?, .float?
      @raw_value.tap { read_next }
    when .string?
      @string_value.to_json.tap { read_next }
    when .begin_array?
      JSON.build { |json| read_raw(json) }
    when .begin_object?
      JSON.build { |json| read_raw(json) }
    else
      unexpected_token
    end
  end

  def read_raw(json)
    case @kind
    when .null?
      read_next
      json.null
    when .bool?
      json.bool(@bool_value)
      read_next
    when .int?, .float?
      json.raw(@raw_value)
      read_next
    when .string?
      json.string(@string_value)
      read_next
    when .begin_array?
      json.array do
        read_begin_array
        until kind.end_array?
          read_raw(json)
        end
        read_end_array
      end
    when .begin_object?
      json.object do
        read_begin_object
        until kind.end_object?
          json.string(@string_value)
          read_object_key
          read_raw(json)
        end
        read_end_object
      end
    else
      unexpected_token
    end
  end

  def read_string
    expect_kind :string
    @string_value.tap { read_next }
  end

  def read_bool_or_null
    read_null_or { read_bool }
  end

  def read_int_or_null
    read_null_or { read_int }
  end

  def read_float_or_null
    read_null_or { read_float }
  end

  def read_string_or_null
    read_null_or { read_string }
  end

  def read_array_or_null
    read_null_or { read_array { yield } }
  end

  def read_object_or_null
    read_null_or { read_object { |key| yield key } }
  end

  def read_null_or
    if @kind.null?
      read_next
      nil
    else
      yield
    end
  end

  def on_key(key)
    read_object do |some_key|
      some_key == key ? yield : skip
    end
  end

  def on_key!(key)
    found = false
    value = uninitialized typeof(yield)

    read_object do |some_key|
      if some_key == key
        found = true
        value = yield
      else
        skip
      end
    end

    unless found
      raise "JSON key not found: #{key}"
    end

    value
  end

  def read_next
    read_next_internal
    @kind
  end

  def read?(klass : Bool.class)
    read_bool if kind.bool?
  end

  {% for type in [Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32] %}
    def read?(klass : {{type}}.class)
      {{type}}.new(int_value).tap { read_next } if kind.int?
    rescue OverflowError
      nil
    end
  {% end %}

  # UInt64 is a special case due to exceeding bounds of @int_value
  def read?(klass : UInt64.class)
    UInt64.new(raw_value).tap { read_next } if kind.int?
  rescue ArgumentError
    nil
  end

  def read?(klass : Float32.class)
    return read_int.to_f32 if kind.int?
    return float_value.to_f32.tap { read_next } if kind.float?
  rescue OverflowError
    nil
  end

  def read?(klass : Float64.class)
    return read_int.to_f64 if kind.int?
    return read_float.to_f64 if kind.float?
  end

  def read?(klass : String.class)
    read_string if kind.string?
  end

  private def read_next_internal
    current_kind = @kind

    while true
      case token.kind
      when .null?
        @kind = :null
        next_token_after_value
        return
      when .true?
        @kind = :bool
        @bool_value = true
        next_token_after_value
        return
      when .false?
        @kind = :bool
        @bool_value = false
        next_token_after_value
        return
      when .int?
        @kind = :int
        @int_value = token.int_value
        @raw_value = token.raw_value
        next_token_after_value
        return
      when .float?
        @kind = :float
        @float_value = token.float_value
        @raw_value = token.raw_value
        next_token_after_value
        return
      when .string?
        @kind = :string
        @string_value = token.string_value
        if current_kind.begin_object?
          unless next_token.kind.colon?
            unexpected_token
          end
        else
          next_token_after_value
        end
        return
      when .begin_array?
        begin_array
        return
      when .end_array?
        @kind = :end_array
        next_token_after_array_or_object
        return
      when .begin_object?
        begin_object
        return
      when .end_object?
        @kind = :end_object
        next_token_after_array_or_object
        return
      when .comma?
        obj = current_object()

        @lexer.skip = false if @skip_count == 1

        if obj.try(&.object?)
          next_token_expect_object_key
        else
          next_token
        end

        @lexer.skip = true if @skip_count == 1

        case token.kind
        when .comma?, .end_array?, .end_object?, .eof?
          unexpected_token
        end

        if obj.try(&.object?) && token.kind.string?
          @kind = :string
          @string_value = token.string_value
          unless next_token.kind.colon?
            unexpected_token
          end
          return
        end
      when .colon?
        case next_token.kind
        when .comma?, .colon?, .end_array?, .end_object?, .eof?
          unexpected_token
        end
      when .eof?
        @kind = :EOF
        return
      else
        unexpected_token
      end
    end
  end

  def skip
    @lexer.skip = true
    skip_internal
    @lexer.skip = false
  end

  def line_number
    @location[0]
  end

  def column_number
    @location[1]
  end

  def location
    @location
  end

  private def skip_internal
    @skip_count += 1
    case @kind
    when .null?, .bool?, .int?, .float?, .string?
      read_next
    when .begin_array?
      @skip_count += 1
      read_begin_array
      until kind.end_array?
        skip_internal
      end
      @skip_count -= 1
      read_end_array
    when .begin_object?
      @skip_count += 1
      read_begin_object
      until kind.end_object?
        read_object_key
        skip_internal
      end
      @skip_count -= 1
      read_end_object
    else
      unexpected_token
    end
    @skip_count -= 1
  end

  private def begin_array
    @kind = :begin_array
    push_in_object_stack :array

    case next_token.kind
    when .comma?, .end_object?, .colon?, .eof?
      unexpected_token
    end
  end

  private def begin_object
    @kind = :begin_object
    push_in_object_stack :object

    case next_token_expect_object_key.kind
    when .string?, .end_object?
      # OK
    else
      unexpected_token
    end
  end

  private def current_object
    @object_stack.last?
  end

  private def token
    @lexer.token
  end

  private def next_token
    @location = {@lexer.token.line_number, @lexer.token.column_number}
    @lexer.next_token
  end

  private def next_token_expect_object_key
    @location = {@lexer.token.line_number, @lexer.token.column_number}
    @lexer.next_token_expect_object_key
  end

  private def next_token_after_value
    case next_token.kind
    when .comma?, .end_array?, .end_object?
      # Ok
    else
      if @object_stack.empty?
        @kind = :EOF
      else
        unexpected_token
      end
    end
  end

  private def next_token_after_array_or_object
    unless @object_stack.pop?
      unexpected_token
    end
    case next_token.kind
    when .comma?, .end_array?, .end_object?
      # OK
    when .eof?
      unless @object_stack.empty?
        unexpected_token
      end
    else
      unexpected_token
    end
  end

  private def expect_kind(kind : Kind)
    parse_exception "Expected #{kind} but was #{@kind}" unless @kind == kind
  end

  private def unexpected_token
    parse_exception "Unexpected token: #{token}"
  end

  private def parse_exception(msg)
    raise ParseException.new(msg, token.line_number, token.column_number)
  end

  private def push_in_object_stack(kind : ObjectStackKind)
    if @object_stack.size >= @max_nesting
      parse_exception "Nesting of #{@object_stack.size + 1} is too deep"
    end

    @object_stack.push(kind)
  end
end
