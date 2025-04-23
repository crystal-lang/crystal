require "./user"

module Crystal::System::Path
  def self.home : String
    if home_path = ENV["HOME"]?.presence
      home_path
    else
      id = LibC.getuid

      pwd = uninitialized LibC::Passwd
      pwd_pointer = Pointer(LibC::Passwd).null
      ret = LibC::Int.new(0)
      System.retry_with_buffer("getpwuid_r", User::GETPW_R_SIZE_MAX) do |buf|
        ret = LibC.getpwuid_r(id, pointerof(pwd), buf, buf.size, pointerof(pwd_pointer)).tap do
          # It's not necessary to check success with `ret == 0` because `pwd_pointer` will be NULL on failure
          return String.new(pwd.pw_dir) if pwd_pointer
        end
      end

      raise RuntimeError.from_os_error("getpwuid_r", Errno.new(ret))
    end
  end
end
