require "crystal/system/windows"

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

module Crystal::System::Group
  def initialize(@name : String, @id : String)
  end

  def system_name : String
    @name
  end

  def system_id : String
    @id
  end

  def self.from_name?(groupname : String) : ::System::Group?
    if found = Crystal::System.name_to_sid(groupname)
      from_sid(found.sid)
    end
  end

  def self.from_id?(groupid : String) : ::System::Group?
    if sid = Crystal::System.sid_from_s(groupid)
      begin
        from_sid(sid)
      ensure
        LibC.LocalFree(sid)
      end
    end
  end

  private def self.from_sid(sid : LibC::SID*) : ::System::Group?
    canonical = Crystal::System.sid_to_name(sid) || return

    # https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/7b2aeb27-92fc-41f6-8437-deb65d950921#gt_0387e636-5654-4910-9519-1f8326cf5ec0
    # SidTypeAlias should also be treated as a group type next to SidTypeGroup
    # and SidTypeWellKnownGroup:
    # "alias object -> resource group: A group object..."
    #
    # Tests show that "Administrators" can be considered of type SidTypeAlias.
    case canonical.type
    when .sid_type_group?, .sid_type_well_known_group?, .sid_type_alias?
      domain_and_group = canonical.domain.empty? ? canonical.name : "#{canonical.domain}\\#{canonical.name}"
      gid = Crystal::System.sid_to_s(sid)
      ::System::Group.new(domain_and_group, gid)
    end
  end
end
