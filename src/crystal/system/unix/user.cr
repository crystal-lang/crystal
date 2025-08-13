require "c/pwd"
require "../unix"

module Crystal::System::User
  GETPW_R_SIZE_MAX = 1024 * 16

  def initialize(@username : String, @id : String, @group_id : String, @name : String, @home_directory : String, @shell : String)
  end

  def system_username
    @username
  end

  def system_id
    @id
  end

  def system_group_id
    @group_id
  end

  def system_name
    @name
  end

  def system_home_directory
    @home_directory
  end

  def system_shell
    @shell
  end

  private def self.from_struct(pwd)
    username = String.new(pwd.pw_name)
    # `pw_gecos` is not part of POSIX and bionic for example always leaves it null
    user = pwd.pw_gecos ? String.new(pwd.pw_gecos).partition(',')[0] : username
    ::System::User.new(username, pwd.pw_uid.to_s, pwd.pw_gid.to_s, user, String.new(pwd.pw_dir), String.new(pwd.pw_shell))
  end

  def self.from_username?(username : String)
    username.check_no_null_byte

    pwd = uninitialized LibC::Passwd
    pwd_pointer = Pointer(LibC::Passwd).null
    System.retry_with_buffer("getpwnam_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwnam_r(username, pointerof(pwd), buf, buf.size, pointerof(pwd_pointer)).tap do
        # It's not necessary to check success with `ret == 0` because `pwd_pointer` will be NULL on failure
        return from_struct(pwd) if pwd_pointer
      end
    end
  end

  def self.from_id?(id : String)
    id = id.to_u32?
    return unless id

    pwd = uninitialized LibC::Passwd
    pwd_pointer = Pointer(LibC::Passwd).null
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwuid_r(id, pointerof(pwd), buf, buf.size, pointerof(pwd_pointer)).tap do
        # It's not necessary to check success with `ret == 0` because `pwd_pointer` will be NULL on failure
        return from_struct(pwd) if pwd_pointer
      end
    end
  end
end
