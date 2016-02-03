require "spec"
require "db"
require "./dummy_driver"

private def connections
  DummyDriver::DummyConnection.connections
end

describe DB do
  it "should get driver class by name" do
    DB.driver_class("dummy").should eq(DummyDriver)
  end

  it "should instantiate driver with connection uri" do
    db = DB.open "dummy://localhost:1027"
    db.driver_class.should eq(DummyDriver)
    db.uri.scheme.should eq("dummy")
    db.uri.host.should eq("localhost")
    db.uri.port.should eq(1027)
  end

  it "should create a connection and close it" do
    cnn = nil
    DB.open "dummy://localhost" do |db|
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

  it "scalar should close statement" do
    with_dummy do |db|
      db.scalar "1"
      DummyDriver::DummyResultSet.last_result_set.closed?.should be_true
    end
  end

  it "initially a single connection should be created" do
    with_dummy do |db|
      connections.size.should eq(1)
    end
  end

  it "the connection should be closed after db usage" do
    with_dummy do |db|
      connections.first.closed?.should be_false
    end
    connections.first.closed?.should be_true
  end
end
