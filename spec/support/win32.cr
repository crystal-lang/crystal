require "spec"

{% if flag?(:win32) %}
  def pending_win32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending("#{description} [win32]", file, line, end_line)
  end

  def pending_win32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending_win32(describe, file, line, end_line) { }
  end
{% else %}
  def pending_win32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    it(description, file, line, end_line, &block)
  end

  def pending_win32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end
{% end %}

# Heuristic to determine the current MSYS2 environment:
#
# - target triple must be `*-windows-gnu`
# - `uname -s` must return `MINGW64_NT*` or `MSYS_NT*`
# - the `MSYSTEM` environment variable must be non-empty
#
# (ideally we should determine the C runtime used at build time, for now we just
# assume the build-time and run-time environments are identical)
def msys2_environment : String?
  {% if flag?(:win32) && flag?(:gnu) %}
    uname = IO::Memory.new
    if Process.run("uname", %w(-s), output: uname).success?
      uname = uname.to_s
      if uname.starts_with?("MINGW64_NT") || uname.starts_with?("MSYS_NT")
        ENV["MSYSTEM"]?.presence
      end
    end
  {% end %}
rescue IO::Error
end
