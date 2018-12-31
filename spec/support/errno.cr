# This spec helper allows to easily test the error code of `Errno` errors.
#
# The error messages returned by `strerror` vary between different libc
# implementations. Error codes are a more reliable way to assert the expected
# kind of error.
#
# *message* should usually only validate parts of the error message added by
# Crystal.
def expect_raises_errno(errno, message = nil, file = __FILE__, line = __LINE__, end_line = __END_LINE__)
  error = expect_raises(Errno, message, file: file, line: line) do
    yield
  end
  error.errno.should eq(errno), file: file, line: line
  error
end
