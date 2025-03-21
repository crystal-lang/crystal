{% begin %}
  def new_thread(name = nil, &block) : Thread
    {% if flag?(:execution_context) %}
      ctx = Fiber::ExecutionContext::Isolated.new(name: name || "SPEC") { block.call }
      ctx.@thread
    {% else %}
      Thread.new(name) { block.call }
    {% end %}
  end
{% end %}
