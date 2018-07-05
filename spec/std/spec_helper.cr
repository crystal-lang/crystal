require "spec"
require "../support/tempfile"

def datapath(*components)
  File.join("spec", "std", "data", *components)
end

{% if flag?(:win32) %}
  def pending_win32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending(description, file, line, end_line, &block)
  end
{% else %}
  def pending_win32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    it(description, file, line, end_line, &block)
  end
{% end %}
