{% if flag?(:win32) %}
  lib LibC
    struct LUID
      lowPart : DWORD
      highPart : Long
    end

    struct LUID_AND_ATTRIBUTES
      luid : LUID
      attributes : DWORD
    end

    struct TOKEN_PRIVILEGES
      privilegeCount : DWORD
      privileges : LUID_AND_ATTRIBUTES[1]
    end

    TOKEN_QUERY             = 0x0008
    TOKEN_ADJUST_PRIVILEGES = 0x0020

    TokenPrivileges = 3

    SE_PRIVILEGE_ENABLED_BY_DEFAULT = 0x00000001_u32
    SE_PRIVILEGE_ENABLED            = 0x00000002_u32

    fun OpenProcessToken(processHandle : HANDLE, desiredAccess : DWORD, tokenHandle : HANDLE*) : BOOL
    fun GetTokenInformation(tokenHandle : HANDLE, tokenInformationClass : Int, tokenInformation : Void*, tokenInformationLength : DWORD, returnLength : DWORD*) : BOOL
    fun LookupPrivilegeValueW(lpSystemName : LPWSTR, lpName : LPWSTR, lpLuid : LUID*) : BOOL
    fun AdjustTokenPrivileges(tokenHandle : HANDLE, disableAllPrivileges : BOOL, newState : TOKEN_PRIVILEGES*, bufferLength : DWORD, previousState : TOKEN_PRIVILEGES*, returnLength : DWORD*) : BOOL
  end

  private SeTimeZonePrivilege = Crystal::System.to_wstr("SeTimeZonePrivilege")

  module Crystal::System::Time
    class_getter? time_zone_privilege_enabled : Bool do
      if LibC.LookupPrivilegeValueW(nil, SeTimeZonePrivilege, out time_zone_luid) == 0
        raise RuntimeError.from_winerror("LookupPrivilegeValueW")
      end

      if LibC.OpenProcessToken(LibC.GetCurrentProcess, LibC::TOKEN_QUERY, out token) != 0
        begin
          LibC.GetTokenInformation(token, LibC::TokenPrivileges, nil, 0, out len)
          buf = Pointer(UInt8).malloc(len).as(LibC::TOKEN_PRIVILEGES*)
          LibC.GetTokenInformation(token, LibC::TokenPrivileges, buf, len, out _)
          privileges = Slice.new(pointerof(buf.value.@privileges).as(LibC::LUID_AND_ATTRIBUTES*), buf.value.privilegeCount)
          return true if privileges.any? { |pr| pr.luid == time_zone_luid && pr.attributes & (LibC::SE_PRIVILEGE_ENABLED_BY_DEFAULT | LibC::SE_PRIVILEGE_ENABLED) != 0 }
        ensure
          LibC.CloseHandle(token)
        end
      end

      if LibC.OpenProcessToken(LibC.GetCurrentProcess, LibC::TOKEN_ADJUST_PRIVILEGES | LibC::TOKEN_QUERY, out adjust_token) != 0
        new_privileges = LibC::TOKEN_PRIVILEGES.new(
          privilegeCount: 1,
          privileges: StaticArray[
            LibC::LUID_AND_ATTRIBUTES.new(
              luid: time_zone_luid,
              attributes: LibC::SE_PRIVILEGE_ENABLED,
            ),
          ],
        )
        if LibC.AdjustTokenPrivileges(adjust_token, 0, pointerof(new_privileges), 0, nil, nil) != 0
          return true
        end
      end

      false
    end
  end

  def with_system_time_zone(tzi : LibC::TIME_ZONE_INFORMATION, *, file = __FILE__, line = __LINE__, &)
    unless Crystal::System::Time.time_zone_privilege_enabled?
      pending! "Unable to set system time zone", file: file, line: line
    end

    LibC.GetTimeZoneInformation(out old_tzi)
    unless LibC.SetTimeZoneInformation(pointerof(tzi)) != 0
      error = WinError.value
      raise RuntimeError.from_os_error("Failed to set system time zone", error) unless error.error_privilege_not_held?
      pending! "Unable to set system time zone", file: file, line: line
    end

    begin
      yield
    ensure
      LibC.SetTimeZoneInformation(pointerof(old_tzi))
    end
  end
{% end %}
