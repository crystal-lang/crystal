require "spec"

{% if flag?(:wasm32) %}
  def pending_wasm32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, tags : String | Enumerable(String) | Nil = nil, &block)
    pending("#{description} [wasm32]", file, line, end_line, tags: tags)
  end

  def pending_wasm32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending_wasm32(describe, file, line, end_line) { }
  end
{% else %}
  def pending_wasm32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, tags : String | Enumerable(String) | Nil = nil, &block)
    it(description, file, line, end_line, tags: tags, &block)
  end

  def pending_wasm32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end
{% end %}
