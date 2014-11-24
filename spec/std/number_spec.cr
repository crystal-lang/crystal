require "spec"

describe "Number" do
  describe "significant" do
    it "10 base " do
      -1763.116.significant(2).should eq(-1800.0)
      753.16.significant(3).should eq(753.0)
      15.159.significant(1).should eq(20.0)
    end

    it "2 base " do
      -1763.116.significant(2, base = 2).should eq(-1536.0)
      753.155.significant(3, base = 2).should eq(768.0)
      15.159.significant(1, base = 2).should eq(16.0)
    end
  end

  describe "round" do
    it "10 base " do
      -1763.116.round(2).should eq(-1763.12)
      753.155.round(2).should eq(753.16)
      15.151.round(2).should eq(15.15)
    end

    it "2 base " do
      -1763.116.round(2, base = 2).should eq(-1763.0)
      753.155.round(2, base = 2).should eq(753.25)
      15.159.round(2, base = 2).should eq(15.25)
    end
  end
end
