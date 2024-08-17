require "spec"

{% if flag?(:wasm32) %}
  def pending_wasm32(description = "assert", file : String = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    pending("#{description} [wasm32]", file, line, end_line, focus: focus, tags: tags)
  end

  def pending_wasm32(*, describe, file : String = __FILE__, line : Int32 = __LINE__, end_line : Int32 = __END_LINE__, &block)
    pending_wasm32(describe, file, line, end_line) { }
  end
{% else %}
  def pending_wasm32(description = "assert", file : String = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
    it(description, file, line, end_line, focus: focus, tags: tags, &block)
  end

  def pending_wasm32(*, describe, file : String = __FILE__, line : Int32 = __LINE__, end_line : Int32 = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end
{% end %}
