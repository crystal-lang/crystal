require "c/pwd"
require "c/sys/limits"

struct System::User
  module Limits
    {% if flag?(:darwin) || flag?(:openbsd) || flag?(:freebsd) %}
      UID_MAX = LibC::UID_MAX
    {% elsif flag?(:linux) %}
      UID_MAX = 0xffffffff_u32
    {% else %}
      UID_MAX = 0xffffffff_u32
    {% end %}
  end

  # Converts user ID into a username.
  #
  # Returns: The username for the given user ID.
  #
  # ```
  # System::User.name(0) # => root
  # ```
  def self.name(uid : Int) : String
    user_struct = LibC.getpwuid(int_to_uid(uid))
    return String.new(user_struct.value.pw_name) if user_struct

    raise NotFoundError.new("User with uid '#{uid}', was not found.")
  end

  # Converts username into user ID.
  #
  # Returns: The user ID for the given username.
  # Raises: User::NotFound error if no user exists with the given username.
  #
  # ```
  # System::User.uid("root") # => 0
  # ```
  def self.uid(user : String) : Int
    user_struct = LibC.getpwnam(user.check_no_null_byte)
    return user_struct.value.pw_uid if user_struct

    raise NotFoundError.new("User with name '#{user}', was not found.")
  end

  # Checks to see if user with a given user ID exists.
  #
  # Returns: `true` if the user exists.
  #
  # ```
  # System::User.exists?("root")             # => true
  # System::User.exists?("nonexistant_user") # => false
  # ```
  def self.exists?(uid : Int) : Bool
    !LibC.getpwuid(int_to_uid(uid)).null?
  end

  # Checks to see if user with a given username exists.
  #
  # Returns: `true` if the user exists.
  #
  # ```
  # System::User.exists?(0)     # => true
  # System::User.exists?(32766) # => false
  # ```
  def self.exists?(user : String) : Bool
    !LibC.getpwnam(user.check_no_null_byte).null?
  end

  # Returns the user specified by the user ID.
  # Raises `System::User::NotFoundError` if not found.
  # ```
  # System::User.get(0)
  # ```
  def self.get(uid : Int) : User
    user_struct = LibC.getpwuid(User.int_to_uid(uid))
    return new(user_struct.value) if user_struct

    raise NotFoundError.new("User with uid '#{uid}', was not found.")
  end

  # Returns the user specified by the username.
  # Returns `nil` if not found.
  # ```
  # System::User.get?(0)
  # ```
  def self.get?(uid : Int) : User?
    user_struct = LibC.getpwuid(User.int_to_uid(uid))
    return new(user_struct.value) if user_struct
    return nil
  end

  # Returns the user specified by the username.
  # Raises `System::User::NotFoundError` if not found.
  # ```
  # System::User.get("root")
  # ```
  def self.get(username : String) : User
    user_struct = LibC.getpwnam(username.check_no_null_byte)
    return new(user_struct.value) if user_struct

    raise NotFoundError.new("User with name '#{username}', was not found.")
  end

  # Returns the user specified by the username.
  # Returns `nil` if not found.
  # ```
  # System::User.get?("root")
  # ```
  def self.get?(username : String) : User?
    user_struct = LibC.getpwnam(username.check_no_null_byte)
    return new(user_struct.value) if user_struct
    return nil
  end

  # Initializes a user for a given users struct.
  private def initialize(user : LibC::Passwd)
    @name = String.new(user.pw_name)
    @uid = user.pw_uid
    @gid = user.pw_gid
    @home = String.new(user.pw_dir)
    @shell = String.new(user.pw_shell)
    @info = String.new(user.pw_gecos)
  end

  # Returns the users name.
  #
  # ```
  # System::User.get(0).name # => "root"
  # ```
  getter name : String

  # Returns the users ID.
  #
  # ```
  # System::User.get("root").uid # => 0
  # ```
  getter uid : UInt32

  # Returns the users group ID.
  #
  # ```
  # System::User.get("root").gid # => 0
  # ```
  getter gid : UInt32

  # Returns the path for the users home.
  #
  # ```
  # System::User.get("root").home # => "/root"
  # ```
  getter home : String

  # Returns the path for the users shell.
  #
  # ```
  # System::User.get("root").shell # => "/bin/ksh"
  # ```
  getter shell : String

  # Returns additional information about the user.
  #
  # ```
  # System::User.get("root").info # => "Charlie Root"
  # ```
  getter info : String

  # Returns the primary group for the user.
  #
  # ```
  # System::User.get("root").group # => Group.get(0)
  # ```
  def group
    Group.get(@gid)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    @uid.hash(hasher)
  end

  # Compares this user with *other*, returning `-1`, `0` or `+1` depending if the
  # user ID is less, equal or greater than the *other* user ID.
  def <=>(other : User) : Int
    @uid <=> other.uid
  end

  # Returns a string representation of the user. It's user name.
  def to_s
    @name
  end

  # Appends the username to the given `IO`.
  def to_s(io : IO)
    io << @name
  end

  # :nodoc:
  def self.check_uid_in_bounds(uid : Int) : Nil
    return if (uid >= 0 && uid <= Limits::UID_MAX)
    raise OutOfBoundsError.new("uid: '#{uid}' is out of bounds.")
  end

  # :nodoc:
  def self.int_to_uid(uid : Int) : LibC::UidT
    check_uid_in_bounds(uid)
    {% if flag?(:linux) || flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
      uid.to_u32
    {% else %}
      uid.to_u16
    {% end %}
  end

  class NotFoundError < Exception; end

  class OutOfBoundsError < Exception; end
end
