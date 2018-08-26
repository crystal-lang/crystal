require "crystal/system/passwd"

struct System::User
  # Returns the user name for the given user ID.
  # Raises `System::User::NotFoundError` if no user exists.
  def self.name(uid : Int | String) : String
    name?(uid) || raise NotFoundError.new("User #{uid.inspect} was not found")
  end

  # Returns the user name for the given user ID.
  # Returns `nil` if no user exists.
  def self.name?(uid : Int | String) : String?
    Crystal::System::Passwd.name?(uid)
  end

  # Passes through the uid or `nil`.
  # This makes it easier to accept multiple representations.
  def self.name?(user : User?) : String?
    return nil if !user
    user.name
  end

  # Returns the user ID for the given user name.
  # Raises `System::User::NotFoundError` if no user exists.
  def self.uid(username : String) : String
    uid?(username) || raise NotFoundError.new("User #{username.inspect} was not found")
  end

  # Returns the user ID for the given user by name or uid.
  # Returns `nil` if no user exists.
  #
  # In the case its given a `User` or `nil` the apropriate uid is passed
  # through.
  # This makes it easier to accept multiple representations.
  def self.uid?(user : User | String | Int | Nil) : String?
    raw_uid?(user).try(&.to_s)
  end

  # Returns the raw user ID for the given user name.
  # Returns `nil` if no user exists.
  def self.raw_uid?(username : String)
    Crystal::System::Passwd.uid?(username)
  end

  # Passes through the raw uid or `nil`.
  # This makes it easier to accept multiple representations.
  def self.raw_uid?(user : User?)
    return nil if !user
    user.raw_uid
  end

  # Passes through the integer uid if valid or returns `nil`.
  # This makes it easier to accept multiple representations.
  def self.raw_uid?(uid : Int)
    return uid if valid_uid?(uid)
    nil
  end

  # Returns the user specified by the users username.
  # Raises `System::User::NotFoundError` if no user exists.
  def self.from_uid(uid : Int | String) : self
    from_uid?(uid) || raise NotFoundError.new("User #{uid.inspect} was not found")
  end

  # Returns the user specified by the users uid.
  # Returns `nil` if not found.
  def self.from_uid?(uid : Int | String) : self?
    pwd = Crystal::System::Passwd.from_uid?(uid)
    return if !pwd
    new(pwd)
  end

  # Returns the user specified by the users username.
  # Raises `System::User::NotFoundError` if no user exists.
  def self.from_username(username : String) : self
    from_username?(username) || raise NotFoundError.new("User #{username.inspect} was not found")
  end

  # Returns the user specified by the users username.
  # Returns `nil` if not found.
  def self.from_username?(username : String) : self?
    pwd = Crystal::System::Passwd.from_username?(username)
    return if !pwd
    new(pwd)
  end

  # Returns the user specified by the user ID or username.
  # Raises `System::User::NotFoundError` if not found.
  #
  # Note: If passed a `String` and it is a valid representation of a uid it
  # will be treated as a uid even if it is a valid username.
  def self.get(uid : Int | String) : User
    get?(uid) || raise NotFoundError.new("User #{uid.inspect} was not found")
  end

  # Returns the user specified by the user ID or username.
  # Returns `nil` if not found.
  def self.get?(uid : Int | String) : User?
    pwd = Crystal::System::Passwd.get?(uid)
    return nil if !pwd
    new(pwd)
  end

  # Passes through the `User` or `nil`.
  # This makes it easier to accept multiple representations.
  def self.get?(user : User?) : User?
    user
  end

  # :nodoc:
  private def initialize(@passwd : Crystal::System::Passwd)
  end

  # Returns the user name as a `String`.
  def name : String
    @passwd.name
  end

  # Returns the user ID in a `String` representation.
  def uid : String
    @passwd.uid
  end

  # Returns the user ID as a `UInt32` on UNIX and a `String` on Windows.
  def raw_uid
    @passwd.@uid
  end

  # Returns the group ID in a `String` representation.
  def gid : String
    @passwd.gid
  end

  # Returns the group ID as a `UInt32` on UNIX and a `String` on Windows.
  def raw_gid : String
    @passwd.@gid
  end

  # Returns the path for the user's home as a `String`.
  def home : String
    @passwd.home
  end

  # Returns the path for the user's shell as a `String`.
  def shell : String
    @passwd.shell
  end

  # Returns additional information about the user as a `String`.
  def info : String
    @passwd.info
  end

  # Returns the primary `Group` for the user.
  def group : Group
    Group.get(@passwd.gid)
  end

  # Returns if the user is root
  def root? : Bool
    @passwd.root?
  end

  def_equals_and_hash(@passwd.uid)

  # Returns a `String` representation of the user, it's user name.
  def to_s
    @passwd.name
  end

  # Appends the user name to the given `IO`.
  def to_s(io : IO)
    io << @passwd.name
  end

  # :nodoc:
  def self.valid_uid?(uid : Int | String | Nil) : Bool
    return Crystal::System::Passwd.valid_uid?(uid)
  end

  class NotFoundError < Exception; end
end
