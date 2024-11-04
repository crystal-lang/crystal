require "spec"

{% if flag?(:interpreted) %}
  def pending_interpreted(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending("#{description} [interpreted]", file, line, end_line)
  end

  def pending_interpreted(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending_interpreted(describe, file, line, end_line) { }
  end

  def pending_interpreted!(msg = "Cannot run example", file = __FILE__, line = __LINE__)
    pending!(msg, file, line)
  end
{% else %}
  def pending_interpreted(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    it(description, file, line, end_line, &block)
  end

  def pending_interpreted(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end

  def pending_interpreted!(msg = "Cannot run example", file = __FILE__, line = __LINE__)
  end
{% end %}
