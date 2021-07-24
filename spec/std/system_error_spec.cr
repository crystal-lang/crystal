require "spec"

describe SystemError do
  describe ".from_os_error" do
    it "Can build an error from an errno" do
      errno = Errno.new(2)
      error = ::IO::Error.from_os_error(message: nil, os_error: errno)
      error.message.should eq("No such file or directory")
    end
  end
end
