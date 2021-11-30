require "c/pwd"
require "../unix"

module Crystal::System::User
  private GETPW_R_SIZE_MAX = 1024 * 16

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

    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    from_struct(pwd) if pwd_pointer
  end
end
