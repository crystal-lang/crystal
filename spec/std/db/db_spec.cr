require "spec"
require "db"
require "./dummy_driver"

describe DB do
  it "should get driver class by name" do
    DB.driver_class("dummy").should eq(DummyDriver)
  end

  it "should instantiate driver with connection_string" do
    db = DB.open "dummy", "localhost:1027"
    db.driver_class.should eq(DummyDriver)
    db.connection_string.should eq("localhost:1027")
  end

  it "should create a connection and close it" do
    cnn = nil
    DB.open "dummy", "localhost" do |db|
      cnn = db.connection
    end

    cnn.should be_a(DummyDriver::DummyConnection)
    cnn.not_nil!.closed?.should be_true
  end

  it "query should close result_set" do
    with_witness do |w|
      with_dummy do |db|
        db.query "1,2" do
          break
        end

        w.check
        DummyDriver::DummyResultSet.last_result_set.closed?.should be_true
      end
    end
  end

  it "exec should close statement" do
    with_dummy do |db|
      db.exec ""
      DummyDriver::DummyResultSet.last_result_set.closed?.should be_true
    end
  end

  it "scalar should close statement" do
    with_dummy do |db|
      db.scalar "1"
      DummyDriver::DummyResultSet.last_result_set.closed?.should be_true
    end
  end

  it "exec should perform statement" do
    with_dummy do |db|
      db.exec ""
      DummyDriver::DummyResultSet.last_result_set.executed?.should be_true
    end
  end
end
