require "c/pwd"

module Crystal::System
  def self.current_user_name
    id = LibC.getuid
    pwd = uninitialized LibC::Passwd
    pwd_pointer = pointerof(pwd)
    System.retry_with_buffer("getpwuid_r", GETPW_R_SIZE_MAX) do |buf|
      LibC.getpwuid_r(id, pwd_pointer, buf, buf.size, pointerof(pwd_pointer))
    end

    unless pwd_pointer
      raise RuntimeError.from_errno("Could not get current user name")
    end

    String.new(pwd.pw_name)
  end
end
