# This class allows you to consume JSON on demand, token by token.
class JSON::PullParser
  getter kind : Symbol
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
    @object_stack = [] of Symbol
    @skip_count = 0
    @location = {0, 0}

    next_token
    case token.type
    when :null
      @kind = :null
    when :false
      @kind = :bool
      @bool_value = false
    when :true
      @kind = :bool
      @bool_value = true
    when :INT
      @kind = :int
      @int_value = token.int_value
      @raw_value = token.raw_value
    when :FLOAT
      @kind = :float
      @float_value = token.float_value
      @raw_value = token.raw_value
    when :STRING
      @kind = :string
      @string_value = token.string_value
    when :"["
      begin_array
    when :"{"
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
    while kind != :end_array
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
    while kind != :end_object
      key = read_object_key
      yield key
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
    when :int
      @int_value.to_f.tap { read_next }
    when :float
      @float_value.tap { read_next }
    else
      parse_exception "expecting int or float but was #{@kind}"
    end
  end

  def read_raw
    case @kind
    when :null
      read_next
      "null"
    when :bool
      @bool_value.to_s.tap { read_next }
    when :int, :float
      @raw_value.tap { read_next }
    when :string
      @string_value.to_json.tap { read_next }
    when :begin_array
      JSON.build { |json| read_raw(json) }
    when :begin_object
      JSON.build { |json| read_raw(json) }
    else
      unexpected_token
    end
  end

  def read_raw(json)
    case @kind
    when :null
      read_next
      json.null
    when :bool
      json.bool(@bool_value)
      read_next
    when :int, :float
      json.raw(@raw_value)
      read_next
    when :string
      json.string(@string_value)
      read_next
    when :begin_array
      json.array do
        read_begin_array
        while kind != :end_array
          read_raw(json)
        end
        read_end_array
      end
    when :begin_object
      json.object do
        read_begin_object
        while kind != :end_object
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
    if @kind == :null
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
    read_bool if kind == :bool
  end

  def read?(klass : Int8.class)
    read_int.to_i8 if kind == :int
  end

  def read?(klass : Int16.class)
    read_int.to_i16 if kind == :int
  end

  def read?(klass : Int32.class)
    read_int.to_i32 if kind == :int
  end

  def read?(klass : Int64.class)
    read_int.to_i64 if kind == :int
  end

  def read?(klass : UInt8.class)
    read_int.to_u8 if kind == :int
  end

  def read?(klass : UInt16.class)
    read_int.to_u16 if kind == :int
  end

  def read?(klass : UInt32.class)
    read_int.to_u32 if kind == :int
  end

  def read?(klass : UInt64.class)
    read_int.to_u64 if kind == :int
  end

  def read?(klass : Float32.class)
    return read_int.to_f32 if kind == :int
    return read_float.to_f32 if kind == :float
  end

  def read?(klass : Float64.class)
    return read_int.to_f64 if kind == :int
    return read_float.to_f64 if kind == :float
  end

  def read?(klass : String.class)
    read_string if kind == :string
  end

  private def read_next_internal
    current_kind = @kind

    while true
      case token.type
      when :null
        @kind = :null
        next_token_after_value
        return
      when :true
        @kind = :bool
        @bool_value = true
        next_token_after_value
        return
      when :false
        @kind = :bool
        @bool_value = false
        next_token_after_value
        return
      when :INT
        @kind = :int
        @int_value = token.int_value
        @raw_value = token.raw_value
        next_token_after_value
        return
      when :FLOAT
        @kind = :float
        @float_value = token.float_value
        @raw_value = token.raw_value
        next_token_after_value
        return
      when :STRING
        @kind = :string
        @string_value = token.string_value
        if current_kind == :begin_object
          if next_token.type != :":"
            unexpected_token
          end
        else
          next_token_after_value
        end
        return
      when :"["
        begin_array
        return
      when :"]"
        @kind = :end_array
        next_token_after_array_or_object
        return
      when :"{"
        begin_object
        return
      when :"}"
        @kind = :end_object
        next_token_after_array_or_object
        return
      when :","
        obj = current_object()

        @lexer.skip = false if @skip_count == 1

        if obj == :object
          next_token_expect_object_key
        else
          next_token
        end

        @lexer.skip = true if @skip_count == 1

        case token.type
        when :",", :"]", :"}", :EOF
          unexpected_token
        end

        if obj == :object && token.type == :STRING
          @kind = :string
          @string_value = token.string_value
          if next_token.type != :":"
            unexpected_token
          end
          return
        end
      when :":"
        case next_token.type
        when :",", :":", :"]", :"}", :EOF
          unexpected_token
        end
      when :EOF
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
    when :null, :bool, :int, :float, :string
      read_next
    when :begin_array
      @skip_count += 1
      read_begin_array
      while kind != :end_array
        skip_internal
      end
      @skip_count -= 1
      read_end_array
    when :begin_object
      @skip_count += 1
      read_begin_object
      while kind != :end_object
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

    case next_token.type
    when :",", :"}", :":", :EOF
      unexpected_token
    end
  end

  private def begin_object
    @kind = :begin_object
    push_in_object_stack :object

    case next_token_expect_object_key.type
    when :STRING, :"}"
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
    case next_token.type
    when :",", :"]", :"}"
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
    case next_token.type
    when :",", :"]", :"}"
      # OK
    when :EOF
      unless @object_stack.empty?
        unexpected_token
      end
    else
      unexpected_token
    end
  end

  private def expect_kind(kind)
    parse_exception "Expected #{kind} but was #{@kind}" unless @kind == kind
  end

  private def unexpected_token
    parse_exception "Unexpected token: #{token}"
  end

  private def parse_exception(msg)
    raise ParseException.new(msg, token.line_number, token.column_number)
  end

  private def push_in_object_stack(symbol)
    if @object_stack.size >= @max_nesting
      parse_exception "Nesting of #{@object_stack.size + 1} is too deep"
    end

    @object_stack.push(symbol)
  end
end
