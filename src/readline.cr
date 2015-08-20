@[Link("readline")]
lib LibReadline
  alias Int = LibC::Int

  fun readline(prompt : UInt8*) : UInt8*
  fun add_history(line : UInt8*)

  alias CPP = (UInt8*, Int, Int) -> UInt8**

  $rl_attempted_completion_function : CPP
  $rl_line_buffer : UInt8*
  $rl_point : Int
end

private def malloc_match(match)
  match_ptr = LibC.malloc(LibC::SizeT.cast(match.bytesize) + 1) as UInt8*
  match_ptr.copy_from(match.to_unsafe, match.bytesize)
  match_ptr[match.bytesize] = 0_u8
  match_ptr
end

module Readline
  extend self

  alias CompletionProc = String -> Array(String)?

  def readline(prompt = "", add_history = false)
    line = LibReadline.readline(prompt)
    if line
      LibReadline.add_history(line) if add_history
      String.new(line).tap { LibC.free(line as Void*) }
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

  # :nodoc:
  def common_prefix_bytesize(str1 : String, str2 : String)
    r1 = CharReader.new str1
    r2 = CharReader.new str2

    while r1.has_next? && r2.has_next?
      break if r1.current_char != r2.current_char

      r1.next_char
      r2.next_char
    end

    r1.pos
  end

  # :nodoc :
  def common_prefix_bytesize(strings : Array)
    str1 = strings[0]
    low = str1.bytesize
    1.upto(strings.length - 1).each do |i|
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
    result = LibC.malloc(LibC::SizeT.cast(sizeof(UInt8*)) * (matches.length + 2)) as UInt8**
    matches.each_with_index do |match, i|
      result[i + 1] = malloc_match(match)
    end
    result[matches.length + 1] = Pointer(UInt8).null

    # The first element is the completion if it's oe
    if matches.length == 1
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
