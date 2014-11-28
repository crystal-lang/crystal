require "spec"

describe "Number" do
  describe "significant" do
    it "10 base " do
      1234.567.significant(1).should eq(1000)
      1234.567.significant(2).should eq(1200)
      1234.567.significant(3).should eq(1230)
      1234.567.significant(4).should eq(1235)
      1234.567.significant(5).should be_close(1234.6, 1e-7)
      1234.567.significant(6).should eq(1234.57)
      1234.567.significant(7).should eq(1234.567)
    end

    it "2 base " do
      -1763.116.significant(2, base = 2).should eq(-1536.0)
      753.155.significant(3, base = 2).should eq(768.0)
      15.159.significant(1, base = 2).should eq(16.0)
    end

    it "8 base " do
      -1763.116.significant(2, base = 8).should eq(-1792.0)
      753.155.significant(3, base = 8).should eq(752.0)
      15.159.significant(1, base = 8).should eq(16.0)
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

    it "8 base " do
      -1763.116.round(2, base = 8).should eq(-1763.109375)
      753.155.round(1, base = 8).should eq(753.125)
      15.159.round(0, base = 8).should eq(15.0)
    end
  end
end
