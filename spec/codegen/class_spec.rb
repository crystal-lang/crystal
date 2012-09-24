require 'spec_helper'

describe 'Code gen: class' do
  it "codegens instace method" do
    run('class Foo; def coco; 1; end; end; Foo.new.coco').to_i.should eq(1)
  end
end
