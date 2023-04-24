# :nodoc:
module Crystal::System
  def self.retry_wstr_buffer(&)
    buffer_arr = uninitialized LibC::WCHAR[256]

    buffer_size = yield buffer_arr.to_slice, true
    buffer = Slice(LibC::WCHAR).new(buffer_size)

    yield buffer, false
    raise "BUG: retry_wstr_buffer returned"
  end

  def self.to_wstr(str : String, name : String? = nil) : LibC::LPWSTR
    str.check_no_null_byte(name).to_utf16.to_unsafe
  end
end
