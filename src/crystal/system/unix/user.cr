require "c/pwd"

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
    initial_buf = uninitialized UInt8[1024]
    buf = initial_buf.to_slice

    ret = LibC.getpwnam_r(username, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    while ret == LibC::ERANGE && buf.size < GETPW_R_SIZE_MAX
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getpwnam_r(username, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    raise RuntimeError.from_errno("getpwnam_r") if ret != 0

    from_struct(pwd) if pwd_pointer
  end

  private def from_id?(id : String)
    id = id.to_u32?
    return unless id

    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    initial_buf = uninitialized UInt8[1024]
    buf = initial_buf.to_slice

    ret = LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    while ret == LibC::ERANGE && buf.size < GETPW_R_SIZE_MAX
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    raise RuntimeError.from_errno("getpwuid_r") if ret != 0

    from_struct(pwd) if pwd_pointer
  end
end
