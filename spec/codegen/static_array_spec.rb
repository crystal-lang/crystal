require 'spec_helper'

describe 'Code gen: static array' do
  it "codegens static array length" do
    run('a = StaticArray.new(2); a.length').to_i.should eq(2)
  end

  it "codegens static array setter and getter" do
    run('a = StaticArray.new(2); a[0] = 1; a[1] = 2; a[0] + a[1]').to_i.should eq(3)
  end

  it "codegens static array setter and getter with union" do
    run('a = StaticArray.new(2); a[0] = 1; a[1] = 1.5; a[0].to_i').to_i.should eq(1)
  end
end
