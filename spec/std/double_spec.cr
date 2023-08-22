require "spec"

describe "Double" do
  describe "**" do
    it { (2.5 ** 2).should be_close(6.25, 0.0001) }
    it { (2.5 ** 2.5_f32).should be_close(9.882117688026186, 0.0001) }
    it { (2.5 ** 2.5).should be_close(9.882117688026186, 0.0001) }
  end
end
