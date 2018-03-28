require "spec"

describe "expectations" do
  context "start_with" do
    it { "1-2-3".should start_with("") }
    it { "1-2-3".should start_with("1") }
    it { "1-2-3".should start_with("1-") }
    it { "1-2-3".should start_with("1-2-3") }
    it { "1-2-3".should_not start_with("2-") }
    it { "1-2-3".should_not start_with("1-2-3-4") }
  end

  context "end_with" do
    it { "1-2-3".should end_with("") }
    it { "1-2-3".should end_with("3") }
    it { "1-2-3".should end_with("-3") }
    it { "1-2-3".should end_with("1-2-3") }
    it { "1-2-3".should_not end_with("-2") }
    it { "1-2-3".should_not end_with("0-1-2-3") }
  end
end
