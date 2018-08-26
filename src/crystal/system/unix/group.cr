require "c/grp"
require "c/sys/limits"

struct Crystal::System::Group
  {% if flag?(:darwin) || flag?(:openbsd) || flag?(:freebsd) %}
    GID_MAX = LibC::GID_MAX
  {% elsif flag?(:linux) %}
    GID_MAX = 0xffffffff_u32
  {% else %}
    {{ raise "Unsupported platform, only Darwin, OpenBSD, FreeBSD, and Linux (GNU, musl) are supported." }}
    #GID_MAX = 0xffff_u32 # POSIX Default
  {% end %}
  NGROUPS_MAX = LibC::NGROUPS_MAX

  private GETGR_R_SIZE_MAX = begin
    size = LibC.sysconf(LibC::SC_GETGR_R_SIZE_MAX)

    # Set default size if sysconf not set
    size < 0 ? 1024 : size
  end

  def self.getgrnam?(groupname : String) : LibC::Group?
    groupname.check_no_null_byte

    grp = uninitialized LibC::Group
    buf = Bytes.new(GETGR_R_SIZE_MAX)
    result = pointerof(grp)

    ret = LibC.getgrnam_r(groupname, pointerof(grp), buf, buf.size, pointerof(result))

    unless result
      return if ret == 0 # not found
      raise Errno.new("getgrnam_r")
    end

    grp
  end

  def self.getgrgid?(gid : String) : LibC::Group?
    gid = to_gid(gid)
    return if !gid
    getgrgid?(gid)
  end

  def self.getgrgid?(gid : Int) : LibC::Group?
    return if !valid_gid?(gid)

    grp = uninitialized LibC::Group
    buf = Bytes.new(GETGR_R_SIZE_MAX)
    result = pointerof(grp)

    ret = LibC.getgrgid_r(gid, pointerof(grp), buf, buf.size, pointerof(result))

    unless result
      return if ret == 0 # not found
      raise Errno.new("getgrgid_r")
    end

    grp
  end

  def self.name?(gid : Int | String) : String?
    grp = getgrgid?(gid)
    return if !grp
    String.new(grp.gr_name)
  end

  def self.gid?(groupname : String) : UInt32?
    grp = getgrnam?(groupname)
    return if !grp
    grp.gr_gid
  end

  def self.from_gid?(gid : Int) : self?
    return if gid == -1

    grp = getgrgid?(gid)
    return if !grp
    new(grp)
  end

  def self.from_gid?(gid : String) : self?
    return if gid == "-1"

    gid = to_gid(gid)
    return if !gid
    from_gid?(gid)
  end

  def self.from_groupname?(groupname : String) : self?
    grp = getgrnam?(groupname)
    return if !grp
    new(grp)
  end

  def self.get?(groupname : String) : self?
    grp = from_gid?(groupname)
    return grp if grp
    from_groupname?(groupname)
  end

  def self.get?(gid : Int) : self?
    from_gid?(gid)
  end

  # :nodoc:
  private def initialize(group : LibC::Group)
    @name = String.new(group.gr_name)
    @gid = group.gr_gid
    slice = Slice.new(group.gr_mem, limit: NGROUPS_MAX, read_only: true)
    @user_names = Array.new(slice.size) { |idx| String.new(slice[idx]) }
  end

  # Returns the group name as a `String`.
  getter name : String

  # Returns the group ID in a `String` representation.
  def gid : String
    @gid.to_s
  end

  @gid : UInt32

  # Returns an `Array` of the user names as `String`s.
  getter user_names : Array(String)

  # Yields user names as `String`s.
  def each_user_name(&block : String -> Nil) : Nil
    @user_names.each { |member| yield(member) }
  end

  # Indicates if the given gid is valid
  def self.valid_gid?(gid : Int?) : Bool
    !gid.nil? && (0 <= gid <= GID_MAX)
  end

  # :ditto:
  def self.valid_gid?(gid : String) : Bool
    valid_gid?(to_gid(gid))
  end

  # :nodoc:
  private def self.to_gid(gid : String) : UInt32?
    gid.to_u32?(10, false, false, false, true)
  end
end
