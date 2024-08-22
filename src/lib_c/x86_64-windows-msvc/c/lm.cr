require "c/winnt"

@[Link("netapi32")]
lib LibC
  alias NET_API_STATUS = DWORD

  NERR_Success = NET_API_STATUS.new!(0)

  enum NETSETUP_JOIN_STATUS
    NetSetupUnknownStatus = 0
    NetSetupUnjoined
    NetSetupWorkgroupName
    NetSetupDomainName
  end

  fun NetGetJoinInformation(lpServer : LPWSTR, lpNameBuffer : LPWSTR*, bufferType : NETSETUP_JOIN_STATUS*) : NET_API_STATUS

  struct USER_INFO_4
    usri4_name : LPWSTR
    usri4_password : LPWSTR
    usri4_password_age : DWORD
    usri4_priv : DWORD
    usri4_home_dir : LPWSTR
    usri4_comment : LPWSTR
    usri4_flags : DWORD
    usri4_script_path : LPWSTR
    usri4_auth_flags : DWORD
    usri4_full_name : LPWSTR
    usri4_usr_comment : LPWSTR
    usri4_parms : LPWSTR
    usri4_workstations : LPWSTR
    usri4_last_logon : DWORD
    usri4_last_logoff : DWORD
    usri4_acct_expires : DWORD
    usri4_max_storage : DWORD
    usri4_units_per_week : DWORD
    usri4_logon_hours : BYTE*
    usri4_bad_pw_count : DWORD
    usri4_num_logons : DWORD
    usri4_logon_server : LPWSTR
    usri4_country_code : DWORD
    usri4_code_page : DWORD
    usri4_user_sid : SID*
    usri4_primary_group_id : DWORD
    usri4_profile : LPWSTR
    usri4_home_dir_drive : LPWSTR
    usri4_password_expired : DWORD
  end

  struct USER_INFO_10
    usri10_name : LPWSTR
    usri10_comment : LPWSTR
    usri10_usr_comment : LPWSTR
    usri10_full_name : LPWSTR
  end

  fun NetUserGetInfo(servername : LPWSTR, username : LPWSTR, level : DWORD, bufptr : BYTE**) : NET_API_STATUS
  fun NetApiBufferFree(buffer : Void*) : NET_API_STATUS
end
