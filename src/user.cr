require "../lib_c/pwd"

class User

  {% if flag?(:linux) || flag?(:darwin) %}
    MAX_UID = 0xFFFFFFF
  {% elsif flag?(:openbsd) || flag?(:freebsd) %}
    MAX_UID = 0xFFFF
  {% else %}
    MAX_UID = 0xFFFF
  {% end %}

  alias UserID = LibC::UidT

  # Converts user ID into a username.
  #
  # Returns: The username for the given user ID.
  #
  # ```
  # User.name(0)
  # => root
  # ```
  def self.name(uid : Int) : String
    check_uid_in_bounds(uid)
    user_struct = LibC.getpwuid(int_to_uid(uid))
    return String.new(user_struct.value.pw_name) if ( !user_struct.null? )
    raise NotFound.new("User with uid '#{uid}', was not found.")
  end

  # Converts username into user ID.
  #
  # Returns: The user ID for the given username.
  # Raises: User::NotFound error if no user exists with the given username.
  #
  # ```
  # User.uid("root")
  # => 0
  # ```
  def self.uid(user : String) : Int
    user_struct = LibC.getpwnam(user.check_no_null_byte)
    return user_struct.value.pw_uid if ( !user_struct.null? )
    raise NotFound.new("User with name '#{user}', was not found.")
  end

  # Checks to see if user with a given user ID exists.
  #
  # Returns: `true` if the user exists.
  #
  # ```
  # User.exists?("root")
  # => true
  # User.exists?("nonexistant_user")
  # => false
  # ```
  def self.exists?(uid : Int) : Bool
    return !LibC.getpwuid(int_to_uid(uid)).null?
  end

  # Checks to see if user with a given username exists.
  #
  # Returns: `true` if the user exists.
  #
  # ```
  # User.exists?(0)
  # => true
  # User.exists?(32766)
  # => false
  # ```
  def self.exists?(user : String) : Bool
    return !LibC.getpwnam(user.check_no_null_byte).null?
  end

  # Returns the user specified by the user ID.
  # ```
  # User[0]
  # ```
  def self.[](uid : Int) : User
    return new(uid)
  end

  # Returns the user specified by the username.
  # ```
  # User["root"]
  # ```
  def self.[](username : String) : User
    return new(username)
  end

  # Returns the user specified by the user ID.
  # ```
  # User.new(0)
  # ```
  def self.new(uid : Int) : User
    check_uid_in_bounds(uid)
    user_struct = LibC.getpwuid(int_to_uid(uid))
    raise NotFound.new("User with uid '#{uid}', was not found.") if ( user_struct.null? )
    return new(user_struct.value)
  end

  # Returns the user specified by the username.
  # ```
  # User.new("root")
  # ```
  def self.new(username : String) : User
    user_struct = LibC.getpwnam(username.check_no_null_byte)
    raise NotFound.new("User with name '#{user}', was not found.") if ( user_struct.null? )
    return new(user_struct.value)
  end

  # :nodoc:
  def initialize(user_struct : LibC::Passwd)
    @name = String.new(user_struct.pw_name)
    @uid = user_struct.pw_uid
    @gid = user_struct.pw_gid
    @home = String.new(user_struct.pw_dir)
    @shell = String.new(user_struct.pw_shell)
    @info = String.new(user_struct.pw_gecos)
  end


  # Properties

  getter(name : String)
  getter(uid :  UserID)
  getter(gid :  UInt32)
  getter(home : String)
  getter(shell : String)
  getter(info : String)


  def group()
    return Group[@gid]
  end


  # Comparison

  def hash()
    return @uid.hash
  end

  def ==(other : User) : Bool
    return (@uid == other.uid)
  end

  def eql?(other : User) : Bool
    return @uid.eql?(other.uid)
  end

  def <=>(other : User) : Int
    return (@uid <=> other.uid)
  end


  # Appends the groupname to the given `IO`.
  def to_s(io : IO)
  	io << @name
  end

  # :nodoc:
  private def check_uid_in_bounds(uid : Int) : Nil
    return if ( uid >= 0 && uid <= MAX_UID )
    raise OutOfBounds.new("uid: '#{uid}' is out of bounds.")
  end

  # :nodoc:
  private def int_to_uid(uid : Int) : LibC::UidT
    {% if flag?(:linux) || flag?(:darwin) %}
      return uid.to_u32
    {% elsif flag?(:openbsd) || flag?(:freebsd) %}
      return uid.to_u16
    {% else %}
      return uid.to_u16
    {% end %}
  end


  # Errors

  class NotFound < Exception; end
  class OutOfBounds < Exception; end

end
