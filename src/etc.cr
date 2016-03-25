lib LibC
  ifdef darwin
    struct Passwd
      name : Char*
      passwd : Char*
      uid : UInt32
      gid : UInt32
      change : TimeT
      pwclass : Char*
      gecos : Char*
      dir : Char*
      shell : Char*
      expire : TimeT
      fields : Int32
    end
  elsif linux
    struct Passwd
      name : Char*
      passwd : Char*
      uid : UInt32
      gid : UInt32
      gecos : Char*
      dir : Char*
      shell : Char*
    end
  end

  fun getlogin : Char*
  fun getpwnam(name : Char*) : Passwd*
  fun getpwuid(uid : UInt32) : Passwd*
  fun getuid : UInt32
end

# The `Etc` module provides access to currently logged in user and
# information typically stored in files in the /etc directory on Unix
# systems.
#
# ### Example
#
#     require "etc"
#
#     login = Etc.getlogin
#     info = Etc.getpwnam(login)
#     full_name = info.gecos.sub(/,.*/, "")
#     puts "Hello #{full_name}!"
#
module Etc
  struct Passwd
    property name
    property passwd
    property uid
    property gid
    property gecos
    property dir
    property shell

    def initialize(pwd : LibC::Passwd)
      initialize(
        safe_string(pwd.name),
        safe_string(pwd.passwd),
        pwd.uid,
        pwd.gid,
        safe_string(pwd.gecos),
        safe_string(pwd.dir),
        safe_string(pwd.shell)
      )
    end

    def initialize(@name, @passwd, @uid, @gid, @gecos, @dir, @shell)
    end

    # :nodoc:
    protected def safe_string(chars : LibC::Char*)
      chars ? String.new(chars) : ""
    end
  end

  # Returns the short user name of the currently logged in user or `nil` if it
  # can't be determined. Note that this information is not secure.
  def self.getlogin
    if login = LibC.getlogin
      String.new(LibC.getlogin)
    else
      ENV["USER"]?
    end
  end

  # Returns a Passwd struct containing the fields of the record in the
  # password database (e.g., the local password file /etc/passwd, NIS, and
  # LDAP) that matches the username `name`.
  #
  # See the unix manpage for `getpwnam(3)` for more detail.
  def self.getpwnam(name : String)
    pwd = LibC.getpwnam(name)
    if pwd.nil?
      raise ArgumentError.new("can't find user for #{name}")
    end
    Passwd.new(pwd.value)
  end

  # Returns a Passwd struct containing the fields of the record in the
  # password database (e.g., the local password file /etc/passwd, NIS, and
  # LDAP) that matches the user ID `uid`.
  #
  # See the unix manpage for `getpwuid(3)` for more detail.
  def self.getpwuid(uid : Number)
    pwd = LibC.getpwuid(uid)
    if pwd.nil?
      raise ArgumentError.new("can't find user for #{uid}")
    end
    Passwd.new(pwd.value)
  end

  # Returns a Passwd struct containing the fields of the record in the
  # password database (e.g., the local password file /etc/passwd, NIS, and
  # LDAP) that matches the current user.
  #
  # See the unix manpage for `getpwuid(3)` for more detail.
  def self.getpwuid
    getpwuid(LibC.getuid)
  end
end
