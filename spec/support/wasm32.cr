require "spec"

{% if flag?(:wasm32) %}
  def pending_wasm32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    pending(_description: "#{description} [wasm32]", _file: file, _line: line, _end_line: end_line, _focus: focus, _tags: tags)
  end

  def pending_wasm32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending_wasm32(describe, file, line, end_line) { }
  end
{% else %}
  def pending_wasm32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    it(description: description, file: file, line: line, end_line: end_line, focus: focus, tags: tags, &block)
  end

  def pending_wasm32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    describe(description: describe, file: file, line: line, end_line: end_line, &block)
  end
{% end %}
