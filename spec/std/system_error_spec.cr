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
      error = ::RuntimeError.from_errno("foobar".tap { Errno.value = :EPERM })
      error.os_error.should eq Errno::ENOENT
    end
  end

  {% if flag?(:win32) %}
    describe ".from_winerror" do
      it "avoid reset from message" do
        WinError.value = :ERROR_FILE_NOT_FOUND
        error = ::RuntimeError.from_winerror("foobar".tap { WinError.value = :ERROR_ACCESS_DENIED })
        error.os_error.should eq WinError::ERROR_ACCESS_DENIED # This should be ERROR_FILE_NOT_FOUND
      end
    end

    describe ".from_wsa_error" do
      it "avoid reset from message" do
        WinError.wsa_value = :ERROR_FILE_NOT_FOUND
        error = ::RuntimeError.from_wsa_error("foobar".tap { WinError.wsa_value = :ERROR_ACCESS_DENIED })
        error.os_error.should eq WinError::ERROR_ACCESS_DENIED # This should be ERROR_FILE_NOT_FOUND
      end
    end
  {% end %}
end
