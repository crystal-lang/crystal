def with_timeout(timeout = 10.seconds, file = __FILE__, line = __LINE__, &block : -> T) forall T
  value = Channel(T).new
  error = Channel(Exception).new

  spawn do
    begin
      value.send block.call
    rescue e
      error.send e
    end
  end

  select
  when val = value.receive
    val
  when e = error.receive
    raise e
  when timeout(timeout)
    fail "Unexpected timeout", file: file, line: line
  end
end
