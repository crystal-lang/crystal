@[Link("readline")]
lib LibReadline
  fun readline(prompt : UInt8*) : UInt8*
  fun add_history(line : UInt8*)

  alias CPP = (UInt8*, Int32, Int32) -> UInt8**

  $rl_attempted_completion_function : CPP
  $rl_line_buffer : UInt8*
  $rl_point : Int32
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

  LibReadline.rl_attempted_completion_function = ->(text_ptr, start, finish) {
    completion_proc = @@completion_proc
    return Pointer(UInt8*).null unless completion_proc

    text = String.new(text_ptr)
    matches = completion_proc.call(text)

    return Pointer(UInt8*).null unless matches
    return Pointer(UInt8*).null if matches.empty?

    result = LibC.malloc(LibC::SizeT.cast(sizeof(UInt8*)) * (matches.length + 1)) as UInt8**
    matches.each_with_index do |match, i|
      match_ptr = LibC.malloc(LibC::SizeT.cast(match.bytesize) + 1) as UInt8*
      match_ptr.copy_from(match.to_unsafe, match.bytesize)
      match_ptr[match.bytesize] = 0_u8
      result[i] = match_ptr
    end
    result[matches.length] = Pointer(UInt8).null
    result
  }
end
