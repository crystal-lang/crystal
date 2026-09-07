{% skip_file if flag?(:without_mt) %}

private SPEC_TIMEOUT = 15.seconds

Spec.around_each do |example|
  done = Channel(Exception?).new

  {% begin %}
  spawn({% if flag?(:preview_mt) && !flag?(:execution_context) %}same_thread: true{% end %}) do
    example.run
  rescue e
    done.send(e)
  else
    done.send(nil)
  end
  {% end %}

  timeout = SPEC_TIMEOUT
  if example.example.all_tags.includes?("slow")
    timeout *= 4
  end

  select
  when res = done.receive
    raise res if res
  when timeout(timeout)
    _it = example.example
    ex = Spec::AssertionFailed.new("spec timed out after #{timeout}", _it.file, _it.line)
    _it.parent.report(:fail, _it.description, _it.file, _it.line, timeout, ex)
  end
end
