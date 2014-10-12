class Json::PullParser
  getter kind
  getter bool_value
  getter int_value
  getter float_value
  getter string_value

  def initialize(input)
    @lexer = Lexer.new input
    @kind = :EOF
    @bool_value = false
    @int_value = 0
    @float_value = 0.0
    @string_value = ""
    @object_stack = [] of Symbol
    @skip_count = 0

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
    when :FLOAT
      @kind = :float
      @float_value = token.float_value
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
    expect_kind :object_key
    @string_value.tap { read_next }
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
    expect_kind :float
    @float_value.tap { read_next }
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

    read_object do |some_key|
      if some_key == key
        found = true
        yield
      else
        skip
      end
    end

    unless found
      raise "json key not found: #{key}"
    end
  end

  def read_next
    read_next_internal
    @kind
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
        next_token_after_value
        return
      when :FLOAT
        @kind = :float
        @float_value = token.float_value
        next_token_after_value
        return
      when :STRING
        if current_kind == :begin_object
          @kind = :object_key
          @string_value = token.string_value
          if next_token.type != :":"
            unexpected_token
          end
        else
          @kind = :string
          @string_value = token.string_value
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
          @kind = :object_key
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
    @object_stack << :array

    case next_token.type
    when :",", :"}", :":", :EOF
      unexpected_token
    end
  end

  private def begin_object
    @kind = :begin_object
    @object_stack << :object

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

  private delegate token, @lexer
  private delegate next_token, @lexer
  private delegate next_token_expect_object_key, @lexer

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
    raise ParseException.new("expected #{kind} but was #{@kind}", token.line_number, token.column_number) unless @kind == kind
  end

  private def unexpected_token
    raise ParseException.new("unexpected token: #{token}", token.line_number, token.column_number)
  end
end
