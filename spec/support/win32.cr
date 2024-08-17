require "spec"

{% if flag?(:win32) %}
  def pending_win32(description = "assert", file : String = __FILE__, line : Int32 = __LINE__, end_line : Int32 = __END_LINE__, &block)
    pending("#{description} [win32]", file, line, end_line)
  end

  def pending_win32(*, describe, file : String = __FILE__, line : Int32 = __LINE__, end_line : Int32 = __END_LINE__, &block)
    pending_win32(describe, file, line, end_line) { }
  end
{% else %}
  def pending_win32(description = "assert", file : String = __FILE__, line : Int32 = __LINE__, end_line : Int32 = __END_LINE__, &block)
    it(description, file, line, end_line, &block)
  end

  def pending_win32(*, describe, file : String = __FILE__, line : Int32 = __LINE__, end_line : Int32 = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end
{% end %}
