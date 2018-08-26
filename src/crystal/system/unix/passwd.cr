require "c/pwd"
require "c/sys/limits"

struct Crystal::System::Passwd
  {% if flag?(:darwin) || flag?(:openbsd) || flag?(:freebsd) %}
    UID_MAX = LibC::UID_MAX
  {% elsif flag?(:linux) %}
    UID_MAX = 0xffffffff_u32
  {% else %}
    {{ raise "Unsupported platform, only Darwin, OpenBSD, FreeBSD, and Linux (GNU, musl) are supported." }}
    #UID_MAX = 0xffff_u32 # POSIX Default
  {% end %}

  private GETPW_R_SIZE_MAX = begin
    size = LibC.sysconf(LibC::SC_GETPW_R_SIZE_MAX)

    # Set default size if sysconf not set
    size < 0 ? 1024 : size
  end

  def self.getpwnam?(username : String) : LibC::Passwd?
    username.check_no_null_byte

    pwd = uninitialized LibC::Passwd
    buf = Bytes.new(GETPW_R_SIZE_MAX)
    result = pointerof(pwd)

    ret = LibC.getpwnam_r(username, pointerof(pwd), buf, buf.size, pointerof(result))

    unless result
      return if ret == 0 # not found
      raise Errno.new("getpwnam_r")
    end

    pwd
  end

  def self.getpwuid?(uid : String) : LibC::Passwd?
    uid = to_uid(uid)
    return if !uid
    getpwuid?(uid)
  end

  def self.getpwuid?(uid : Int) : LibC::Passwd?
    return if !valid_uid?(uid)

    pwd = uninitialized LibC::Passwd
    buf = Bytes.new(GETPW_R_SIZE_MAX)
    result = pointerof(pwd)

    ret = LibC.getpwuid_r(uid, pointerof(pwd), buf, buf.size, pointerof(result))

    unless result
      return if ret == 0 # not found
      raise Errno.new("getpwuid_r")
    end

    pwd
  end

  def self.name?(uid : Int | String) : String?
    return if uid == -1
    pwd = getpwuid?(uid)
    return if !pwd
    String.new(pwd.pw_name)
  end

  def self.uid?(username : String) : UInt32?
    pwd = getpwnam?(username)
    return if !pwd
    pwd.pw_uid
  end

  def self.from_uid?(uid : Int) : self?
    return if uid == -1

    pwd = getpwuid?(uid)
    return if !pwd
    new(pwd)
  end

  def self.from_uid?(uid : String) : self?
    return if uid == "-1"

    uid = to_uid(uid)
    return if !uid
    from_uid?(uid)
  end

  def self.from_username?(username : String) : self?
    pwd = getpwnam?(username)
    return if !pwd
    new(pwd)
  end

  def self.get?(username : String) : self?
    pwd = from_uid?(username)
    return pwd if pwd
    from_username?(username)
  end

  def self.get?(uid : Int) : self?
    from_uid?(uid)
  end

  private def initialize(user : LibC::Passwd)
    @name = String.new(user.pw_name)
    @uid = user.pw_uid
    @gid = user.pw_gid
    @home = String.new(user.pw_dir)
    @shell = String.new(user.pw_shell)
    @info = String.new(user.pw_gecos)
  end

  # Returns the user name as a `String`.
  getter name : String

  # Returns the user ID in a `String` representation.
  def uid : String
    return @uid.to_s
  end

  @uid : UInt32

  # Returns the group ID in a `String` representation.
  def gid : String
    @gid.to_s
  end

  @gid : UInt32

  # Returns the path for the user's home as a `String`.
  getter home : String

  # Returns the path for the user's shell as a `String`.
  getter shell : String

  # Returns additional information about the user as a `String`.
  getter info : String

  # Returns if the user is root
  def root? : Bool
    @uid == 0
  end

  # Indicates if the given uid is valid
  def self.valid_uid?(uid : Int?) : Bool
    !uid.nil? && (0 <= uid <= UID_MAX)
  end

  # :ditto:
  def self.valid_uid?(uid : String) : Bool
    valid_uid?(to_uid(uid))
  end

  # :nodoc:
  private def self.to_uid(uid : String) : UInt32?
    uid.to_u32?(10, false, false, false, true)
  end
end
