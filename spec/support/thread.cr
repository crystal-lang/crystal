{% begin %}
  def new_thread(name = nil, &block)
    {% if !flag?(:without_mt) %}
      Fiber::ExecutionContext::Isolated.new(name: name || "SPEC") { block.call }
    {% else %}
      Thread.new(name) { block.call }
    {% end %}
  end
{% end %}
