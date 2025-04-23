require "crystal/system/windows"
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
    if found = Crystal::System.name_to_sid(username)
      if found.type.sid_type_user?
        from_sid(found.sid)
      end
    end
  end

  def self.from_id?(id : String) : ::System::User?
    if sid = Crystal::System.sid_from_s(id)
      begin
        from_sid(sid)
      ensure
        LibC.LocalFree(sid)
      end
    end
  end

  private def self.from_sid(sid : LibC::SID*) : ::System::User?
    canonical = Crystal::System.sid_to_name(sid) || return
    return unless canonical.type.sid_type_user?

    domain_and_user = "#{canonical.domain}\\#{canonical.name}"
    full_name = lookup_full_name(canonical.name, canonical.domain, domain_and_user) || return
    pgid = lookup_primary_group_id(canonical.name, canonical.domain) || return
    uid = Crystal::System.sid_to_s(sid)
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

    info = uninitialized LibC::USER_INFO_10*
    if LibC.NetUserGetInfo(Crystal::System.to_wstr(domain), Crystal::System.to_wstr(name), 10, pointerof(info).as(LibC::BYTE**)) == LibC::NERR_Success
      begin
        str, _ = String.from_utf16(info.value.usri10_full_name)
        return str
      ensure
        LibC.NetApiBufferFree(info)
      end
    end

    # domain worked neither as a domain nor as a server
    # could be domain server unavailable
    # pretend username is fullname
    name
  end

  # obtains the primary group SID for a user using this method:
  # https://support.microsoft.com/en-us/help/297951/how-to-use-the-primarygroupid-attribute-to-find-the-primary-group-for
  # The method follows this formula: domainRID + "-" + primaryGroupRID
  private def self.lookup_primary_group_id(name : String, domain : String) : String?
    domain_sid = Crystal::System.name_to_sid(domain) || return
    return unless domain_sid.type.sid_type_domain?

    domain_sid_str = Crystal::System.sid_to_s(domain_sid.sid)

    # If the user has joined a domain use the RID of the default primary group
    # called "Domain Users":
    # https://support.microsoft.com/en-us/help/243330/well-known-security-identifiers-in-windows-operating-systems
    # SID: S-1-5-21domain-513
    #
    # The correct way to obtain the primary group of a domain user is
    # probing the user primaryGroupID attribute in the server Active Directory:
    # https://learn.microsoft.com/en-us/windows/win32/adschema/a-primarygroupid
    #
    # Note that the primary group of domain users should not be modified
    # on Windows for performance reasons, even if it's possible to do that.
    # The .NET Developer's Guide to Directory Services Programming - Page 409
    # https://books.google.bg/books?id=kGApqjobEfsC&lpg=PA410&ots=p7oo-eOQL7&dq=primary%20group%20RID&hl=bg&pg=PA409#v=onepage&q&f=false
    return "#{domain_sid_str}-513" if domain_joined?

    # For non-domain users call NetUserGetInfo() with level 4, which
    # in this case would not have any network overhead.
    # The primary group should not change from RID 513 here either
    # but the group will be called "None" instead:
    # https://www.adampalmer.me/iodigitalsec/2013/08/10/windows-null-session-enumeration/
    # "Group 'None' (RID: 513)"
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
    # If this user has logged in at least once their home path should be stored
    # in the registry under the specified SID. References:
    # https://social.technet.microsoft.com/wiki/contents/articles/13895.how-to-remove-a-corrupted-user-profile-from-the-registry.aspx
    # https://support.asperasoft.com/hc/en-us/articles/216127438-How-to-delete-Windows-user-profiles
    #
    # The registry is the most reliable way to find the home path as the user
    # might have decided to move it outside of the default location,
    # (e.g. C:\users). Reference:
    # https://answers.microsoft.com/en-us/windows/forum/windows_7-security/how-do-i-set-a-home-directory-outside-cusers-for-a/aed68262-1bf4-4a4d-93dc-7495193a440f
    reg_home_dir = WindowsRegistry.open?(LibC::HKEY_LOCAL_MACHINE, REGISTRY_PROFILE_LIST) do |key_handle|
      WindowsRegistry.open?(key_handle, uid.to_utf16) do |sub_handle|
        WindowsRegistry.get_string(sub_handle, ProfileImagePath)
      end
    end
    return reg_home_dir if reg_home_dir

    # If the home path does not exist in the registry, the user might
    # have not logged in yet; fall back to using getProfilesDirectory().
    # Find the username based on a SID and append that to the result of
    # getProfilesDirectory(). The domain is not relevant here.
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

  private def self.domain_joined? : Bool
    status = LibC.NetGetJoinInformation(nil, out domain, out type)
    if status != LibC::NERR_Success
      raise RuntimeError.from_os_error("NetGetJoinInformation", WinError.new(status))
    end
    is_domain = type.net_setup_domain_name?
    LibC.NetApiBufferFree(domain)
    is_domain
  end
end
