require "spec"

{% if flag?(:interpreted) %}
  def pending_interpreter(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending("#{description} [interpreter]", file, line, end_line)
  end

  def pending_interpreter(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending_interpreter(describe, file, line, end_line) { }
  end
{% else %}
  def pending_interpreter(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    it(description, file, line, end_line, &block)
  end

  def pending_interpreter(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end
{% end %}
