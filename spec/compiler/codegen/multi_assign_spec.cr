require "../../spec_helper"

describe "Code gen: multi assign" do
  context "preview_multi_assign" do
    it "raises if value size in 1-to-n assignment doesn't match target count" do
      run(%(
        require "prelude"

        begin
          a, b = [1, 2, 3]
          4
        rescue ex : Exception
          raise ex unless ex.message == "Multiple assignment count mismatch"
          5
        end
        ), flags: %w(preview_multi_assign)).to_i.should eq(5)
    end
  end
end
