require "c/sddl"

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

  def self.sid_to_s(sid : LibC::SID*) : String
    if LibC.ConvertSidToStringSidW(sid, out ptr) == 0
      raise RuntimeError.from_winerror("ConvertSidToStringSidW")
    end
    str, _ = String.from_utf16(ptr)
    LibC.LocalFree(ptr)
    str
  end

  def self.sid_from_s(str : String) : LibC::SID*
    status = LibC.ConvertStringSidToSidW(to_wstr(str), out sid)
    status != 0 ? sid : Pointer(LibC::SID).null
  end

  record SIDLookupResult, sid : LibC::SID*, domain : String, type : LibC::SID_NAME_USE

  def self.name_to_sid(name : String) : SIDLookupResult?
    utf16_name = to_wstr(name)

    sid_size = LibC::DWORD.zero
    domain_buf_size = LibC::DWORD.zero
    LibC.LookupAccountNameW(nil, utf16_name, nil, pointerof(sid_size), nil, pointerof(domain_buf_size), out _)

    unless WinError.value.error_none_mapped?
      sid = Pointer(UInt8).malloc(sid_size).as(LibC::SID*)
      domain_buf = Slice(LibC::WCHAR).new(domain_buf_size)
      if LibC.LookupAccountNameW(nil, utf16_name, sid, pointerof(sid_size), domain_buf, pointerof(domain_buf_size), out sid_type) != 0
        domain = String.from_utf16(domain_buf[..-2])
        SIDLookupResult.new(sid, domain, sid_type)
      end
    end
  end

  record NameLookupResult, name : String, domain : String, type : LibC::SID_NAME_USE

  def self.sid_to_name(sid : LibC::SID*) : NameLookupResult?
    name_buf_size = LibC::DWORD.zero
    domain_buf_size = LibC::DWORD.zero
    LibC.LookupAccountSidW(nil, sid, nil, pointerof(name_buf_size), nil, pointerof(domain_buf_size), out _)

    unless WinError.value.error_none_mapped?
      name_buf = Slice(LibC::WCHAR).new(name_buf_size)
      domain_buf = Slice(LibC::WCHAR).new(domain_buf_size)
      if LibC.LookupAccountSidW(nil, sid, name_buf, pointerof(name_buf_size), domain_buf, pointerof(domain_buf_size), out sid_type) != 0
        name = String.from_utf16(name_buf[..-2])
        domain = String.from_utf16(domain_buf[..-2])
        NameLookupResult.new(name, domain, sid_type)
      end
    end
  end
end
