require "spec"

describe SystemError do
  describe ".from_os_error" do
    it "Can build an error from an errno" do
      errno = Errno::ENOENT
      error = ::RuntimeError.from_os_error(message: nil, os_error: errno)
      error.message.should eq("No such file or directory")
    end
  end

  describe ".from_errno" do
    it "captures `Errno.value`" do
      Errno.value = :ENOENT
      error = ::RuntimeError.from_errno "foobar"
      error.os_error.should eq Errno::ENOENT
    end

    it "avoid reset from message" do
      Errno.value = :ENOENT
      error = ::RuntimeError.from_errno(message: "foobar".tap { Errno.value = :EPERM })
      error.os_error.should eq Errno::ENOENT
    end
  end
end
