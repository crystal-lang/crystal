{% skip_file unless flag?(:preview_mt) %}

private SPEC_TIMEOUT = 15.seconds

Spec.around_each do |example|
  done = Channel(Exception?).new

  spawn(same_thread: true) do
    begin
      example.run
    rescue e
      done.send(e)
    else
      done.send(nil)
    end
  end

  select
  when res = done.receive
    raise res if res
  when timeout(SPEC_TIMEOUT)
    _it = example.example
    ex = Spec::AssertionFailed.new("spec timeout", _it.file, _it.line)
    _it.parent.report(:fail, _it.description, _it.file, _it.line, SPEC_TIMEOUT, ex)
  end
end
