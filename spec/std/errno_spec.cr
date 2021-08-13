require "spec"

describe Errno do
  it ".value" do
    Errno.value = Errno::EACCES
    Errno.value.should eq Errno::EACCES
    Errno.value = Errno::EPERM
    Errno.value.should eq Errno::EPERM
  end

  it "#message" do
    Errno::EACCES.message.should eq "Permission denied"
  end
end
