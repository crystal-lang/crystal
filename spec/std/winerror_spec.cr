require "spec"

describe WinError do
  it ".value" do
    {% if flag?(:win32) %}
      WinError.value = WinError::ERROR_SUCCESS
      WinError.value.should eq WinError::ERROR_SUCCESS
      WinError.value = WinError::ERROR_BROKEN_PIPE
      WinError.value.should eq WinError::ERROR_BROKEN_PIPE
    {% else %}
      expect_raises(NotImplementedError) do
        WinError.value = WinError::ERROR_SUCCESS
      end
      expect_raises(NotImplementedError) do
        WinError.value
      end
    {% end %}
  end

  it "#message" do
    message = WinError::ERROR_SUCCESS.message
    {% if flag?(:win32) %}
      # Not testing for specific content because the result is locale-specific
      # and currently the message uses only default `LANGID`.
      message.empty?.should be_false
    {% else %}
      message.should eq ""
    {% end %}
  end
end
