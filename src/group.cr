require "../lib_c/grp"

class Group

  {% if flag?(:linux) || flag?(:darwin) %}
    MAX_GID = 0xFFFFFFF
  {% elsif flag?(:openbsd) || flag?(:freebsd) %}
    MAX_GID = 0xFFFF
  {% else %}
    MAX_GID = 0xFFFF
  {% end %}

  alias GroupID = LibC::GidT

  # Converts group ID into a groupname.
  #
  # Returns: The groupname for the given group ID.
  #
  # ```
  # Group.name(0)
  # => root
  # ```
  def self.name(gid : Int) : String
    check_gid_in_bounds(gid)
    group_struct = LibC.getgrgid(int_to_gid(gid))
    return String.new(group_struct.value.gr_name) if ( !group_struct.null? )
    raise NotFound.new("Group with gid '#{gid}', was not found.")
  end

  # Converts groupname into group ID.
  #
  # Returns: The group ID for the given groupname.
  # Raises: Group::NotFound error if no group exists with the given groupname.
  #
  # ```
  # Group.gid("root")
  # => 0
  # ```
  def self.gid(group : String) : Int
    group_struct = LibC.getgrnam(group.check_no_null_byte)
    return group_struct.value.gr_gid if ( !group_struct.null? )
    raise NotFound.new("Group with name '#{group}', was not found.")
  end

  # Checks to see if a group with the given group ID exists.
  #
  # Returns: `true` if the group exists.
  #
  # ```
  # Group.exists?("root")
  # => true
  # Group.exists?("nonexistant_group")
  # => false
  # ```
  def self.exists?(gid : Int) : Bool
    return !LibC.getgrgid(int_to_gid(gid)).null?
  end

  # Checks to see if group with a given groupname exists.
  #
  # Returns: `true` if the group exists.
  #
  # ```
  # Group.exists?(0)
  # => true
  # Group.exists?(32766)
  # => false
  # ```
  def self.exists?(group : String) : Bool
    return !LibC.getgrnam(group.check_no_null_byte).null?
  end

  # Returns the group specified by the group ID.
  # ```
  # Group[0]
  # ```
  def self.[](gid : Int) : Group
    return new(gid)
  end

  # Returns the group specified by the groupname.
  # ```
  # Group["root"]
  # ```
  def self.[](groupname : String) : Group
    return new(groupname)
  end

  # Returns the group specified by the group ID.
  # ```
  # Group.new(0)
  # ```
  def self.new(gid : Int) : Group
    check_gid_in_bounds(uid)
    group_struct = LibC.getgrgid(int_to_gid(gid))
    raise NotFound.new("Group with gid '#{gid}', was not found.") if ( group_struct.null? )
    return new(group_struct.value)
  end

  # Returns the group specified by the groupname.
  # ```
  # Group.new("root")
  # ```
  def self.new(groupname : String) : Group
    group_struct = LibC.getgrnam(groupname.check_no_null_byte)
    raise NotFound.new("Group with name '#{group}', was not found.") if ( group_struct.null? )
    return new(group_struct.value)
  end


  # :nodoc:
  def initialize(group_struct : LibC::Group)
    @name = String.new(group_struct.gr_name)
    @gid = group_struct.gr_gid
    @member_names = Array(String).new(group_struct.gr_mem)
  end


  # Properties

  getter(name : String)
  getter(gid : GroupID)
  getter(member_names : Array(String))


  def member_names(&block) : Nil
    @members.each() { |member| yield(member) }
  end

  def members() : Array(User)
    return @members.map() { |member| next User[member] }
  end

  def members(&block) : Nil
    @members.each() { |member|
      next yield(User[member])
    }
  end


  # Comparison

  def hash()
    return @gid.hash
  end

  def ==(other : Group) : Bool
    return (@gid == other.gid)
  end

  def eql?(other : Group) : Bool
    return @gid.eql?(other.gid)
  end

  def <=>(other : Group) : Int
    return (@gid <=> other.gid)
  end


  # Appends the groupname to the given `IO`.
  def to_s(io : IO)
  	io << @name
  end

  # :nodoc:
  private def check_gid_in_bounds(gid : Int) : Nil
    return if ( gid >= 0 && gid <= MAX_GID )
    raise OutOfBounds.new("gid: '#{gid}' is out of bounds.")
  end

  # :nodoc:
  private def int_to_gid(gid : Int) : LibC::GidT
    {% if flag?(:linux) || flag?(:darwin) %}
      return gid.to_u32
    {% elsif flag?(:openbsd) || flag?(:freebsd) %}
      return gid.to_u16
    {% else %}
      return gid.to_u16
    {% end %}
  end

  # Errors

  class NotFound < Exception; end
  class OutOfBounds < Exception; end

end
