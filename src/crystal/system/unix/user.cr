require "c/pwd"

module Crystal::System::User
  private def from_struct(pwd)
    new(String.new(pwd.pw_name), pwd.pw_uid, pwd.pw_gid, String.new(pwd.pw_dir), String.new(pwd.pw_shell))
  end

  def from_name?(username : String)
    username.check_no_null_byte

    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    buf = Bytes.new(1024)

    ret = LibC.getpwnam_r(username, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    while ret == LibC::ERANGE
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getpwnam_r(username, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    raise Errno.new("getpwnam_r") if ret != 0
    return if pwd_pointer.null?

    from_struct(pwd)
  end

  def from_id?(id : LibC::UidT)
    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    buf = Bytes.new(1024)

    ret = LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    while ret == LibC::ERANGE
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    raise Errno.new("getpwuid_r") if ret != 0
    return nil if pwd_pointer.null?

    from_struct(pwd)
  end
end
