@[Link("readline")]
{% if flag?(:openbsd) %}
@[Link("termcap")]
{% end %}
lib LibReadline
  alias Int = LibC::Int

  fun readline(prompt : UInt8*) : UInt8*
  fun add_history(line : UInt8*)
  fun rl_bind_key(key : Int, f : Int, Int -> Int) : Int
  fun rl_unbind_key(key : Int) : Int

  alias CPP = (UInt8*, Int, Int) -> UInt8**

  $rl_attempted_completion_function : CPP
  $rl_line_buffer : UInt8*
  $rl_point : Int
  $rl_done : Int
end

private def malloc_match(match)
  match_ptr = LibC.malloc(match.bytesize + 1).as(UInt8*)
  match_ptr.copy_from(match.to_unsafe, match.bytesize)
  match_ptr[match.bytesize] = 0_u8
  match_ptr
end

module Readline
  extend self

  alias CompletionProc = String -> Array(String)?

  alias KeyBindingProc = Int32, Int32 -> Int32
  KeyBindingHandler = ->(count : LibReadline::Int, key : LibReadline::Int) do
    if (handlers = @@key_bind_handlers) && handlers[key.to_i32]?
      res = handlers[key].call(count.to_i32, key.to_i32)
      LibReadline::Int.new(res)
    else
      LibReadline::Int.new(1)
    end
  end

  def readline(prompt = "", add_history = false)
    line = LibReadline.readline(prompt)
    if line
      LibReadline.add_history(line) if add_history
      String.new(line).tap { LibC.free(line.as(Void*)) }
    else
      nil
    end
  end

  def autocomplete(&@@completion_proc : CompletionProc)
  end

  def line_buffer
    line = LibReadline.rl_line_buffer
    return nil unless line

    String.new(line)
  end

  def point
    LibReadline.rl_point
  end

  def bind_key(c : Char, &f : KeyBindingProc)
    raise ArgumentError.new "Not a valid ASCII character: '#{c.inspect}'" unless 0 <= c.ord <= 255

    handlers = (@@key_bind_handlers ||= {} of LibReadline::Int => KeyBindingProc)
    handlers[c.ord] = f

    res = LibReadline.rl_bind_key(c.ord, KeyBindingHandler).to_i32
    raise ArgumentError.new "Invalid key: '#{c.inspect}'" unless res == 0
  end

  def unbind_key(c : Char)
    if (handlers = @@key_bind_handlers) && handlers[c.ord]?
      handlers.delete(c.ord)
      res = LibReadline.rl_unbind_key(c.ord).to_i32
      raise Exception.new "Error unbinding key: '#{c.inspect}'" unless res == 0
    else
      raise KeyError.new "Key not bound: '#{c.inspect}'"
    end
  end

  def done
    LibReadline.rl_done != 0
  end

  def done=(val : Bool)
    LibReadline.rl_done = val.hash
  end

  # :nodoc:
  def common_prefix_bytesize(str1 : String, str2 : String)
    r1 = Char::Reader.new str1
    r2 = Char::Reader.new str2

    while r1.has_next? && r2.has_next?
      break if r1.current_char != r2.current_char

      r1.next_char
      r2.next_char
    end

    r1.pos
  end

  # :nodoc:
  def common_prefix_bytesize(strings : Array)
    str1 = strings[0]
    low = str1.bytesize
    1.upto(strings.size - 1).each do |i|
      str2 = strings[i]
      low2 = common_prefix_bytesize(str1, str2)
      low = low2 if low2 < low
    end
    low
  end

  LibReadline.rl_attempted_completion_function = ->(text_ptr, start, finish) {
    completion_proc = @@completion_proc
    return Pointer(UInt8*).null unless completion_proc

    text = String.new(text_ptr)
    matches = completion_proc.call(text)

    return Pointer(UInt8*).null unless matches
    return Pointer(UInt8*).null if matches.empty?

    # We *must* to create the results using malloc (readline later frees that).
    # We create an extra result for the first element.
    result = LibC.malloc(sizeof(UInt8*) * (matches.size + 2)).as(UInt8**)
    matches.each_with_index do |match, i|
      result[i + 1] = malloc_match(match)
    end
    result[matches.size + 1] = Pointer(UInt8).null

    # The first element is the completion if it's oe
    if matches.size == 1
      result[0] = malloc_match(matches[0])
    else
      # Otherwise, we compute the common prefix of all matches
      low = Readline.common_prefix_bytesize(matches)
      sub = matches[0].byte_slice(0, low)
      result[0] = malloc_match(sub)
    end
    result
  }
end
