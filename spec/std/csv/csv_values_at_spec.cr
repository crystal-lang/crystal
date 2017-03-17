require "spec"
require "csv"

describe CSV do
  describe "CSV::Row#values_at" do
    context "values_at(*columns : Int)" do
      it "returns a Tuple(String, String) for each row" do
        expected = [{"John", "20"}, {"Peter", "30"}]
        got = [] of Tuple(String, String)

        CSV.new("John,20\nPeter,30").each do |itself|
          got << itself.row.values_at(0, -1)
        end

        got.should eq expected
      end
    end

    context "values_at(*headers : String)" do
      it "returns a Tuple(String, String) for each row" do
        expected = [{"John", "20"}, {"Peter", "30"}]
        got = [] of Tuple(String, String)

        CSV.new("Name,Age\nJohn,20\nPeter,30", headers: true).each do |itself|
          got << itself.row.values_at("Name", "Age")
        end

        got.should eq expected
      end
    end
  end
end
