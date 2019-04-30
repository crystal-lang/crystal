require "c/pwd"

class Crystal::System::User
  getter name : String
  getter password : String
  getter user_id : LibC::UidT
  getter group_id : LibC::GidT
  getter directory : String
  getter shell : String

  private def initialize(@name, @password, @user_id, @group_id, @directory, @shell)
  end

  private def self.from_struct(pwd)
    new(String.new(pwd.pw_name), String.new(pwd.pw_passwd), pwd.pw_uid, pwd.pw_gid, String.new(pwd.pw_dir), String.new(pwd.pw_shell))
  end

  def self.from_name?(username : String)
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

    self.from_struct(pwd)
  end

  def self.from_id?(id : LibC::UidT)
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

    self.from_struct(pwd)
  end
end
