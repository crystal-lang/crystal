{% skip_file if flag?(:without_mt) %}

private SPEC_TIMEOUT = 15.seconds

module Spec
  class Example
    # Defined inside the `Spec` namespace to have access to the protected
    # `ExampleGroup#report`
    def report_timeout(timeout)
      ex = Spec::AssertionFailed.new("spec timed out after #{timeout}", file, line)
      parent.report(:fail, description, file, line, timeout, ex)
    end
  end
end

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
    example.example.report_timeout(timeout)
  end
end
