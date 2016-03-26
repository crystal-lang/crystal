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
  # A struct containing fields of a record in the password database.
  #
  # See the unix manpage for `getpwnam(3)` for more detail.
  record Passwd, name, passwd, uid, gid, gecos, dir, shell

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
    convert_passwd(pwd.value)
  end

  # Returns a Passwd struct containing the fields of the record in the
  # password database (e.g., the local password file /etc/passwd, NIS, and
  # LDAP) that matches the specified user ID, or current user if called
  # without arguments.
  #
  # ```
  # require "etc"
  #
  # pwd = Etc.getpwuid(1000)
  # current_user = Etc.getpwuid
  # ```
  #
  # See the unix manpage for `getpwuid(3)` for more detail.
  def self.getpwuid(uid : Number)
    pwd = LibC.getpwuid(uid)
    if pwd.nil?
      raise ArgumentError.new("can't find user for #{uid}")
    end
    convert_passwd(pwd.value)
  end

  # ditto
  def self.getpwuid
    getpwuid(LibC.getuid)
  end

  # :nodoc:
  protected def self.convert_passwd(pwd : LibC::Passwd)
    Passwd.new(
      safe_string(pwd.name),
      safe_string(pwd.passwd),
      pwd.uid,
      pwd.gid,
      safe_string(pwd.gecos),
      safe_string(pwd.dir),
      safe_string(pwd.shell)
    )
  end

  # :nodoc:
  protected def self.safe_string(chars : LibC::Char*)
    chars ? String.new(chars) : ""
  end
end
