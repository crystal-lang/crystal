require "spec"

describe Order do
  describe Order::LT do
    it "'s value is -1" do
      Order::LT.value.should eq(-1)
    end

    it "is reversed, then it is GT" do
      Order::LT.reverse.should eq Order::GT
    end

    it "mean 'lesser than'" do
      Order::LT.lt?.should be_true
      Order::LT.lt_eq?.should be_true
    end

    it "dosen't means 'equal' or 'greater than'" do
      Order::LT.eq?.should be_false
      Order::LT.gt?.should be_false
      Order::LT.gt_eq?.should be_false
    end
  end

  describe Order::EQ do
    it "'s value is 0" do
      Order::EQ.value.should eq 0
    end

    it "is reversed, then it is EQ" do
      Order::EQ.reverse.should eq Order::EQ
    end

    it "means 'equal'" do
      Order::EQ.eq?.should be_true
      Order::EQ.lt_eq?.should be_true
      Order::EQ.gt_eq?.should be_true
    end

    it "dosen't mean 'lesser than' or 'greater than'" do
      Order::EQ.lt?.should be_false
      Order::EQ.gt?.should be_false
    end
  end

  describe Order::GT do
    it "'s value is 1" do
      Order::GT.value.should eq 1
    end

    it "is reversed, then it is LT" do
      Order::GT.reverse.should eq Order::LT
    end

    it "mean 'greater than'" do
      Order::GT.gt?.should be_true
      Order::GT.gt_eq?.should be_true
    end

    it "dosen't means 'equal' or 'lesser than'" do
      Order::GT.eq?.should be_false
      Order::GT.lt?.should be_false
      Order::GT.lt_eq?.should be_false
    end
  end
end
