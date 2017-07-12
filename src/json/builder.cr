# A JSON builder generates valid JSON.
#
# A `JSON::Error` is raised if attempting to generate an invalid JSON
# (for example, if invoking `end_array` without a matching `start_array`,
# or trying to use a non-string value as an object's field name).
class JSON::Builder
  private getter io

  record StartState
  record DocumentStartState
  record ArrayState, empty : Bool
  record ObjectState, empty : Bool, name : Bool
  record DocumentEndState

  alias State = StartState | DocumentStartState | ArrayState | ObjectState | DocumentEndState

  @indent : String?

  # Creates a `JSON::Builder` that will write to the given `IO`.
  def initialize(@io : IO)
    @state = [StartState.new] of State
    @current_indent = 0
  end

  # Starts a document.
  def start_document
    case state = @state.last
    when StartState
      @state[-1] = DocumentStartState.new
    when DocumentEndState
      @state[-1] = DocumentStartState.new
    else
      raise JSON::Error.new("Starting document before ending previous one")
    end
  end

  # Signals the end of a JSON document.
  def end_document : Nil
    case state = @state.last
    when StartState
      raise JSON::Error.new("Empty JSON")
    when DocumentStartState
      raise JSON::Error.new("Empty JSON")
    when ArrayState
      raise JSON::Error.new("Unterminated JSON array")
    when ObjectState
      raise JSON::Error.new("Unterminated JSON object")
    end
  end

  def document
    start_document
    yield.tap { end_document }
  end

  # Writes a `null` value.
  def null
    scalar do
      @io << "null"
    end
  end

  # Writes a boolean value.
  def bool(value : Bool)
    scalar do
      @io << value
    end
  end

  # Writes an integer.
  def number(number : Int)
    scalar do
      @io << number
    end
  end

  # Writes a float.
  def number(number : Float)
    scalar do
      case number
      when .nan?
        raise JSON::Error.new("NaN not allowed in JSON")
      when .infinite?
        raise JSON::Error.new("Infinity not allowed in JSON")
      else
        @io << number
      end
    end
  end

  # Writes a string. The given *value* is first converted to a `String`
  # by invoking `to_s` on it.
  #
  # This method can also be used to write the name of an object field.
  def string(value)
    string = value.to_s
    scalar(string: true) do
      io << '"'
      string.each_char do |char|
        case char
        when '\\'
          io << "\\\\"
        when '"'
          io << "\\\""
        when '\b'
          io << "\\b"
        when '\f'
          io << "\\f"
        when '\n'
          io << "\\n"
        when '\r'
          io << "\\r"
        when '\t'
          io << "\\t"
        when .ascii_control?
          io << "\\u"
          ord = char.ord
          io << '0' if ord < 0x1000
          io << '0' if ord < 0x100
          io << '0' if ord < 0x10
          ord.to_s(16, io)
        else
          io << char
        end
      end
      io << '"'
    end
  end

  # Writes a raw value, considered a scalar, directly into
  # the IO without processing. This is the only method that
  # might lead to invalid JSON being generated, so you must
  # be sure that *string* contains a valid JSON string.
  def raw(string : String)
    scalar do
      @io << string
    end
  end

  # Writes the start of an array.
  def start_array
    start_scalar
    @current_indent += 1
    @state.push ArrayState.new(empty: true)
    @io << "["
  end

  # Writes the end of an array.
  def end_array
    case state = @state.last
    when ArrayState
      @state.pop
    else
      raise JSON::Error.new("Can't do end_array: not inside an array")
    end
    write_indent state
    @io << "]"
    @current_indent -= 1
    end_scalar
  end

  # Writes the start of an array, invokes the block,
  # and the writes the end of it.
  def array
    start_array
    yield.tap { end_array }
  end

  # Writes the start of an object.
  def start_object
    start_scalar
    @current_indent += 1
    @state.push ObjectState.new(empty: true, name: true)
    @io << "{"
  end

  # Writes the end of an object.
  def end_object
    case state = @state.last
    when ObjectState
      unless state.name
        raise JSON::Error.new("Missing object value")
      end
      @state.pop
    else
      raise JSON::Error.new("Can't do end_object: not inside an object")
    end
    write_indent state
    @io << "}"
    @current_indent -= 1
    end_scalar
  end

  # Writes the start of an object, invokes the block,
  # and the writes the end of it.
  def object
    start_object
    yield.tap { end_object }
  end

  # Writes a scalar value.
  def scalar(value : Nil)
    null
  end

  # ditto
  def scalar(value : Bool)
    bool(value)
  end

  # ditto
  def scalar(value : Int | Float)
    number(value)
  end

  # ditto
  def scalar(value : String)
    string(value)
  end

  # Writes an object's field and value.
  # The field's name is first converted to a `String` by invoking
  # `to_s` on it.
  def field(name, value)
    string(name)
    value.to_json(self)
  end

  # Writes an object's field and then invokes the block.
  # This is equivalent of invoking `string(value)` and then
  # invoking the block.
  def field(name)
    string(name)
    yield
  end

  # Flushes the underlying `IO`.
  def flush
    @io.flush
  end

  # Sets the indent *string*.
  def indent=(string : String)
    if string.empty?
      @indent = nil
    else
      @indent = string
    end
  end

  # Sets the indent *level* (number of spaces).
  def indent=(level : Int)
    if level < 0
      @indent = nil
    else
      @indent = " " * level
    end
  end

  private def scalar(string = false)
    start_scalar(string)
    yield.tap { end_scalar(string) }
  end

  private def start_scalar(string = false)
    object_value = false
    case state = @state.last
    when StartState
      raise JSON::Error.new("Write before start_document")
    when DocumentEndState
      raise JSON::Error.new("Write past end_document and before start_document")
    when ArrayState
      comma unless state.empty
    when ObjectState
      if state.name && !string
        raise JSON::Error.new("Expected string for object name")
      end
      comma if state.name && !state.empty
      object_value = !state.name
    end
    write_indent unless object_value
  end

  private def end_scalar(string = false)
    case state = @state.last
    when DocumentStartState
      @state[-1] = DocumentEndState.new
    when ArrayState
      @state[-1] = ArrayState.new(empty: false)
    when ObjectState
      colon if state.name
      @state[-1] = ObjectState.new(empty: false, name: !state.name)
    end
  end

  private def comma
    @io << ","
  end

  private def colon
    @io << ":"
    @io << " " if @indent
  end

  private def newline
    @io << "\n"
  end

  private def write_indent
    indent = @indent
    return unless indent

    return if @current_indent == 0

    write_indent(indent, @current_indent)
  end

  private def write_indent(state : State)
    return if state.empty

    indent = @indent
    return unless indent

    write_indent(indent, @current_indent - 1)
  end

  private def write_indent(indent, times)
    newline
    times.times do
      @io << indent
    end
  end
end

module JSON
  # Returns the resulting `String` of writing JSON to the yielded `JSON::Builder`.
  #
  # ```
  # require "json"
  #
  # string = JSON.build do |json|
  #   json.object do
  #     json.field "name", "foo"
  #     json.field "values" do
  #       json.array do
  #         json.number 1
  #         json.number 2
  #         json.number 3
  #       end
  #     end
  #   end
  # end
  # string # => %<{"name":"foo","values":[1,2,3]}>
  # ```
  def self.build(indent = nil)
    String.build do |str|
      build(str, indent) do |json|
        yield json
      end
    end
  end

  # Writes JSON into the given `IO`. A `JSON::Builder` is yielded to the block.
  def self.build(io : IO, indent = nil)
    builder = JSON::Builder.new(io)
    builder.indent = indent if indent
    builder.document do
      yield builder
    end
  end
end
