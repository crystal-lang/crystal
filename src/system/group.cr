require "crystal/system/group"

struct System::Group
  # Returns the group name for the given group ID.
  # Raises `System::Group::NotFoundError` if group does not exist.
  def self.name(gid : Int | String) : String
    name?(gid) || raise NotFoundError.new("Group #{gid.inspect} was not found")
  end

  # Returns the group name for the given group ID.
  # Returns `nil` if no group exists.
  def self.name?(gid : Int | String) : String?
    Crystal::System::Group.name?(gid)
  end

  # Passes through the gid or `nil`.
  # This makes it easier to accept multiple representations.
  def self.name?(group : Group?) : String?
    return nil if !group
    group.name
  end

  # Returns the group ID for the given group name.
  # Raises `System::Group::NotFoundError` if group does not exist.
  def self.gid(groupname : String) : String
    gid?(groupname) || raise NotFoundError.new("Group #{groupname.inspect} was not found")
  end

  # Returns the user ID for the given user by name or uid.
  # Returns `nil` if no user exists.
  #
  # In the case its given a `User` or `nil` the apropriate uid is passed
  # through.
  # This makes it easier to accept multiple representations.
  def self.gid?(user : Group | String | Int | Nil) : String?
    raw_gid?(user).try(&.to_s)
  end

  # Returns the raw group ID for the given group name.
  # Returns `nil` if no group exists.
  def self.raw_gid?(groupname : String)
    Crystal::System::Group.gid?(groupname)
  end

  # Passes through the raw gid or `nil`.
  # This makes it easier to accept multiple representations.
  def self.raw_gid?(group : Group?)
    return nil if !group
    group.raw_gid
  end

  # Passes through the integer gid if valid or returns `nil`.
  # This makes it easier to accept multiple representations.
  def self.raw_gid?(gid : Int)
    return gid if valid_gid?(gid)
    nil
  end

  # Returns the group specified by the groups groupname.
  # Raises `System::Group::NotFoundError` if no group exists.
  def self.from_gid(gid : Int | String) : self
    from_gid?(gid) || raise NotFoundError.new("Group #{gid.inspect} was not found")
  end

  # Returns the group specified by the groups gid.
  # Returns `nil` if not found.
  def self.from_gid?(gid : Int | String) : self?
    grp = Crystal::System::Group.from_gid?(gid)
    return if !grp
    new(grp)
  end

  # Returns the group specified by the groups groupname.
  # Raises `System::Group::NotFoundError` if no group exists.
  def self.from_groupname(groupname : String) : self
    from_groupname?(groupname) || raise NotFoundError.new("Group #{groupname.inspect} was not found")
  end

  # Returns the group specified by the groups groupname.
  # Returns `nil` if not found.
  def self.from_groupname?(groupname : String) : self?
    grp = Crystal::System::Group.from_groupname?(groupname)
    return if !grp
    new(grp)
  end

  # Returns the group specified by the group ID.
  # Raises `System::Group::NotFoundError` if not found.
  def self.get(gid : Int | String) : Group
    get?(gid) || raise NotFoundError.new("Group #{gid.inspect} was not found")
  end

  # Returns the group specified by the group ID.
  # Returns `nil` if not found.
  def self.get?(gid : Int | String) : Group?
    grp = Crystal::System::Group.get?(gid)
    return nil if !grp
    new(grp)
  end

  # Passes through the `Group` or `nil`.
  # This makes it easier to accept multiple representations.
  def self.get?(group : Group?) : Group?
    group
  end

  # :nodoc:
  private def initialize(@group : Crystal::System::Group)
  end

  # Returns the group name as a `String`.
  def name : String
    @group.name
  end

  # Returns the group ID in a `String` representation.
  def gid : String
    @group.gid
  end

  # Returns the group ID as a `UInt32` on UNIX and a `String` on Windows.
  def raw_gid
    @group.@gid
  end

  # Returns an `Array` of the user names as `String`s.
  def user_names : Array(String)
    @group.user_names
  end

  # Yields user names as `String`s.
  def each_user_name(&block) : String
    @group.each_user_name() { |name| yield(name) }
  end

  # Returns an `Array` of the users as `User`s.
  def users : Array(User)
    user_names.map { |member| User.get(member) }
  end

  # Yields each user as `User`s.
  def each_user(&block : User -> Nil) : Nil
    each_user_name { |member| yield(User.get(member)) }
  end

  def_equals_and_hash(gid)

  # Returns a `String` representation of the group, it's group name.
  def to_s
    @group.name
  end

  # Appends the group name to the given `IO`.
  def to_s(io : IO)
    io << @group.name
  end

  # :nodoc:
  def self.valid_gid?(gid : Int | String | Nil) : Bool
    return Crystal::System::Group.valid_gid?(gid)
  end

  class NotFoundError < Exception; end
end
