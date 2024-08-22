require "c/sddl"
require "c/lm"
require "c/userenv"
require "c/security"

# This file contains source code derived from the following:
#
# * https://cs.opensource.google/go/go/+/refs/tags/go1.23.0:src/os/user/lookup_windows.go
# * https://cs.opensource.google/go/go/+/refs/tags/go1.23.0:src/syscall/security_windows.go
#
# The following is their license:
#
# Copyright 2009 The Go Authors.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#    * Neither the name of Google LLC nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Crystal::System::User
  def initialize(@username : String, @id : String, @group_id : String, @name : String, @home_directory : String)
  end

  def system_username
    @username
  end

  def system_id
    @id
  end

  def system_group_id
    @group_id
  end

  def system_name
    @name
  end

  def system_home_directory
    @home_directory
  end

  def system_shell
    Crystal::System::User.cmd_path
  end

  class_getter(cmd_path : String) do
    "#{Crystal::System::Path.known_folder_path(LibC::FOLDERID_System)}\\cmd.exe"
  end

  def self.from_username?(username : String) : ::System::User?
    if found = name_to_sid(username)
      if found.type.sid_type_user?
        from_sid(found.sid)
      end
    end
  end

  def self.from_id?(id : String) : ::System::User?
    if sid = sid_from_s(id)
      begin
        from_sid(sid)
      ensure
        LibC.LocalFree(sid)
      end
    end
  end

  private def self.from_sid(sid : LibC::SID*) : ::System::User?
    canonical = sid_to_name(sid) || return
    return unless canonical.type.sid_type_user?

    domain_and_user = "#{canonical.domain}\\#{canonical.name}"
    full_name = lookup_full_name(canonical.name, canonical.domain, domain_and_user) || return
    pgid = lookup_primary_group_id(canonical.name, canonical.domain) || return
    uid = sid_to_s(sid)
    home_dir = lookup_home_directory(uid, canonical.name) || return

    ::System::User.new(domain_and_user, uid, pgid, full_name, home_dir)
  end

  private def self.lookup_full_name(name : String, domain : String, domain_and_user : String) : String?
    if domain_joined?
      domain_and_user = Crystal::System.to_wstr(domain_and_user)
      Crystal::System.retry_wstr_buffer do |buffer, small_buf|
        len = LibC::ULong.new(buffer.size)
        if LibC.TranslateNameW(domain_and_user, LibC::EXTENDED_NAME_FORMAT::NameSamCompatible, LibC::EXTENDED_NAME_FORMAT::NameDisplay, buffer, pointerof(len)) != 0
          return String.from_utf16(buffer[0, len - 1])
        elsif small_buf && len > 0
          next len
        else
          break
        end
      end
    end

    lookup_full_name_server(name, domain) || name
  end

  private def self.lookup_full_name_server(name, domain)
    info = uninitialized LibC::USER_INFO_10*
    if LibC.NetUserGetInfo(Crystal::System.to_wstr(domain), Crystal::System.to_wstr(name), 10, pointerof(info).as(LibC::BYTE**)) == LibC::NERR_Success
      begin
        str, _ = String.from_utf16(info.value.usri10_full_name)
        str
      ensure
        LibC.NetApiBufferFree(info)
      end
    end
  end

  private def self.lookup_primary_group_id(name : String, domain : String) : String?
    domain_sid = name_to_sid(domain) || return
    return unless domain_sid.type.sid_type_domain?

    domain_sid_str = sid_to_s(domain_sid.sid)
    return "#{domain_sid_str}-513" if domain_joined?

    info = uninitialized LibC::USER_INFO_4*
    if LibC.NetUserGetInfo(Crystal::System.to_wstr(domain), Crystal::System.to_wstr(name), 4, pointerof(info).as(LibC::BYTE**)) == LibC::NERR_Success
      begin
        "#{domain_sid_str}-#{info.value.usri4_primary_group_id}"
      ensure
        LibC.NetApiBufferFree(info)
      end
    end
  end

  private REGISTRY_PROFILE_LIST = %q(SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList).to_utf16
  private ProfileImagePath      = "ProfileImagePath".to_utf16

  private def self.lookup_home_directory(uid : String, username : String) : String?
    reg_home_dir = WindowsRegistry.open?(LibC::HKEY_LOCAL_MACHINE, REGISTRY_PROFILE_LIST) do |key_handle|
      WindowsRegistry.open?(key_handle, uid.to_utf16) do |sub_handle|
        WindowsRegistry.get_string(sub_handle, ProfileImagePath)
      end
    end
    return reg_home_dir if reg_home_dir

    # NOTE: the user has not logged in so this directory might not exist
    profile_dir = Crystal::System.retry_wstr_buffer do |buffer, small_buf|
      len = LibC::DWORD.new(buffer.size)
      if LibC.GetProfilesDirectoryW(buffer, pointerof(len)) != 0
        break String.from_utf16(buffer[0, len - 1])
      elsif small_buf && len > 0
        next len
      else
        break nil
      end
    end
    return "#{profile_dir}\\#{username}" if profile_dir
  end

  private record SIDLookupResult, sid : LibC::SID*, domain : String, type : LibC::SID_NAME_USE

  private def self.name_to_sid(name : String) : SIDLookupResult?
    utf16_name = Crystal::System.to_wstr(name)

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

  private record NameLookupResult, name : String, domain : String, type : LibC::SID_NAME_USE

  private def self.sid_to_name(sid : LibC::SID*) : NameLookupResult?
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

  private def self.domain_joined? : Bool
    status = LibC.NetGetJoinInformation(nil, out domain, out type)
    if status != LibC::NERR_Success
      raise RuntimeError.from_os_error("NetGetJoinInformation", WinError.new(status))
    end
    is_domain = type.net_setup_domain_name?
    LibC.NetApiBufferFree(domain)
    is_domain
  end

  private def self.sid_to_s(sid : LibC::SID*) : String
    if LibC.ConvertSidToStringSidW(sid, out ptr) == 0
      raise RuntimeError.from_winerror("ConvertSidToStringSidW")
    end
    str, _ = String.from_utf16(ptr)
    LibC.LocalFree(ptr)
    str
  end

  private def self.sid_from_s(str : String) : LibC::SID*
    status = LibC.ConvertStringSidToSidW(Crystal::System.to_wstr(str), out sid)
    status != 0 ? sid : Pointer(LibC::SID).null
  end
end
