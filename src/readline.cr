lib LibReadline("readline")
  fun readline(prompt : UInt8*) : UInt8*
  fun add_history(line : UInt8*)
end

module Readline
  def self.readline(prompt, add_history = false)
    line = LibReadline.readline(prompt.cstr)
    if line
      LibReadline.add_history(line) if add_history
      String.new(line)
    else
      nil
    end
  end
end
