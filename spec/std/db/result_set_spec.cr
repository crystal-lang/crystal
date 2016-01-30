require "spec"
require "db"
require "./dummy_driver"

describe DB::ResultSet do
  it "should enumerate records using each" do
    nums = [] of Int32

    with_dummy do |db|
      db.query "3,4 1,2" do |rs|
        rs.each do
          nums << rs.read(Int32)
          nums << rs.read(Int32)
        end
      end
    end

    nums.should eq([3, 4, 1, 2])
  end
end
