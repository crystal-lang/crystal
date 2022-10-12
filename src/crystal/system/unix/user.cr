require "c/pwd"
require "../unix"

module Crystal::System::User
  GETPW_R_SIZE_MAX = 1024 * 16

  private def from_struct(pwd)
    user = String.new(pwd.pw_gecos).partition(',')[0]
    new(String.new(pwd.pw_name), pwd.pw_uid.to_s, pwd.pw_gid.to_s, user, String.new(pwd.pw_dir), String.new(pwd.pw_shell))
  end

  private def from_username?(username : String)
    username.check_no_null_byte

    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwnam_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwnam_r(username, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    from_struct(pwd) if pwd_pointer
  end

  private def from_id?(id : String)
    id = id.to_u32?
    return unless id

    pwd = getpwuid(id)
    from_struct(pwd) if pwd
  end

  # Returns the current user's name on success, nil on failure.
  #
  # This deals with the passwd struct direclty to avoid creating strings
  # for the other fields in the passwd struct for the common case of
  # getting the current username
  private def find_current_user_name : String?
    pwd = getpwuid(LibC.getuid)
    return unless pwd

    String.new(pwd.pw_name)
  end

  # Returns a libc passwd struct on success, nil on failure
  private def getpwuid(id : UInt32) : LibC::Passwd?
    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    return unless pwd_pointer
    pwd
  end
end
