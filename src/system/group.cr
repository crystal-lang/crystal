require "c/grp"
require "c/sys/limits"

struct System::Group
  module Limits
    {% if flag?(:darwin) || flag?(:openbsd) || flag?(:freebsd) %}
      GID_MAX = LibC::GID_MAX
    {% elsif flag?(:linux) %}
      GID_MAX = 0xffffffff_u32
    {% else %}
      GID_MAX = 0xffffffff_u32
    {% end %}
    NGROUPS_MAX = LibC::NGROUPS_MAX
  end

  # Converts group ID into a groupname.
  #
  # Returns: The groupname for the given group ID.
  #
  # ```
  # System::Group.name(0) # => root
  # ```
  def self.name(gid : Int) : String
    group_struct = LibC.getgrgid(int_to_gid(gid))
    return String.new(group_struct.value.gr_name) if group_struct

    raise NotFoundError.new("Group with gid '#{gid}', was not found.")
  end

  # Converts groupname into group ID.
  #
  # Returns: The group ID for the given groupname.
  # Raises: Group::NotFound error if no group exists with the given groupname.
  #
  # ```
  # System::Group.gid("root") # => 0
  # ```
  def self.gid(group : String) : Int
    group_struct = LibC.getgrnam(group.check_no_null_byte)
    return group_struct.value.gr_gid if group_struct

    raise NotFoundError.new("Group with name '#{group.to_s}', was not found.")
  end

  # Checks to see if a group with the given group ID exists.
  #
  # Returns: `true` if the group exists.
  #
  # ```
  # System::Group.exists?("root")              # => true
  # System::Group.exists?("nonexistant_group") # => false
  # ```
  def self.exists?(gid : Int) : Bool
    !LibC.getgrgid(int_to_gid(gid)).null?
  end

  # Checks to see if group with a given groupname exists.
  #
  # Returns: `true` if the group exists.
  #
  # ```
  # System::Group.exists?(0)       # => true
  # System::Group.exists?(1234567) # => false
  # ```
  def self.exists?(group : String) : Bool
    !LibC.getgrnam(group.check_no_null_byte).null?
  end

  # Returns the group specified by the group ID.
  # Raises `System::Group::NotFoundError` if not found.
  # ```
  # System::Group.get(0)
  # ```
  def self.get(gid : Int) : Group
    group_struct = LibC.getgrgid(Group.int_to_gid(gid))
    return new(group_struct.value) if group_struct

    raise NotFoundError.new("Group with gid '#{gid}', was not found.")
  end

  # Returns the user specified by the group ID.
  # Returns `nil` if not found.
  # ```
  # System::Group.get?(0)
  # ```
  def self.get?(gid : Int) : Group?
    group_struct = LibC.getgrgid(Group.int_to_gid(gid))
    return new(group_struct.value) if group_struct
    return nil
  end

  # Returns the group specified by the groupname.
  # Raises `System::Group::NotFoundError` if not found.
  # ```
  # System::Group.get("wheel")
  # ```
  def self.get(groupname : String) : Group
    group_struct = LibC.getgrnam(groupname.check_no_null_byte)
    return new(group_struct.value) if group_struct

    raise NotFoundError.new("Group with name '#{groupname}', was not found.")
  end

  # Returns the user specified by the username.
  # Returns `nil` if not found.
  # ```
  # System::Group.get?("wheel")
  # ```
  def self.get?(groupname : String) : Group?
    group_struct = LibC.getgrnam(groupname.check_no_null_byte)
    return new(group_struct.value) if group_struct
    return nil
  end

  # Initializes a group for a given group struct
  private def initialize(group : LibC::Group)
    @name = String.new(group.gr_name)
    @gid = group.gr_gid
    slice = group.gr_mem.to_slice_null_terminated(LibC::NGROUPS_MAX)
    @member_names = Array.new(slice.size) { |idx| String.new(slice[idx]) }
  end

  # Returns the groups name.
  #
  # ```
  # System::Group.get(0).name # => "root"
  # ```
  getter name : String

  # Returns the group ID.
  #
  # ```
  # System::Group.get("root").gid # => 0
  # ```
  getter gid : UInt32

  # Returns an array of the groups members names.
  #
  # ```
  # System::Group.get("root").member_names
  # ```
  getter member_names : Array(String)

  # Yields the groups members names.
  #
  # ```
  # System::Group.get("root").member_names() { |name| puts names }
  # ```
  def each_member_name(&block : String ->) : Nil
    @member_names.each { |member| yield(member) }
  end

  # Returns an array of the groups members.
  #
  # ```
  # System::Group.get("root").members
  # ```
  def members : Array(User)
    @member_names.map { |member| User.get(member) }
  end

  # Yields the groups members.
  #
  # ```
  # System::Group.get("root").members() { |user| puts user.name }
  # ```
  def each_member(&block : User ->) : Nil
    each_member_name { |member| yield(User.get(member)) }
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    @gid.hash(hasher)
  end

  # Compares this group with *other*, returning `-1`, `0` or `+1` depending if the
  # group ID is less, equal or greater than the *other* group ID.
  def <=>(other : Group) : Int
    @gid <=> other.gid
  end

  # Returns a string representation of the group. It's group name.
  def to_s
    @name
  end

  # Appends the username to the given `IO`.
  def to_s(io : IO)
    io << @name
  end

  # :nodoc:
  def self.check_gid_in_bounds(gid : Int) : Nil
    return if (gid >= 0) && (gid <= Limits::GID_MAX)
    raise OutOfBoundsError.new("gid: '#{gid}' is out of bounds.")
  end

  # :nodoc:
  def self.int_to_gid(gid : Int) : LibC::GidT
    check_gid_in_bounds(gid)
    {% if flag?(:linux) || flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      gid.to_u32
    {% else %}
      gid.to_u16
    {% end %}
  end

  class NotFoundError < Exception; end

  class OutOfBoundsError < Exception; end
end
