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
