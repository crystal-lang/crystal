require 'spec_helper'

describe 'Parser: location' do
  context "line numbers" do
    it "stores line numbers" do
      nodes = parse "1 + 2\n3 + 3"
      nodes[0].line_number.should eq(1)
      nodes[0].obj.line_number.should eq(1)
      nodes[0].args[0].line_number.should eq(1)
      nodes[1].line_number.should eq(2)
    end

    it "stores column numbers" do
      nodes = parse "1 + 2\n  call  arg1,  arg2"
      nodes[0].column_number.should eq(1)
      nodes[0].name_column_number.should eq(3)
      nodes[0].obj.column_number.should eq(1)
      nodes[0].args[0].column_number.should eq(5)
      nodes[1].column_number.should eq(3)
      nodes[1].name_column_number.should eq(3)
      nodes[1].args[0].column_number.should eq(9)
      nodes[1].args[1].column_number.should eq(16)
    end
  end
end
