require 'spec_helper'

describe 'Code gen: class' do
  it "codegens instace method" do
    run('class Foo; def coco; 1; end; end; Foo.new.coco').to_i.should eq(1)
  end

  it "codegens instance var" do
  	run(%Q(
			class Foo
				def set(value)
					@coco = value
				end

				def get
					@coco
				end
			end

			f = Foo.new
			f.set 2

			g = Foo.new
			g.set 0.5

			f.get + g.get
  		)).to_f.should eq(2.5)
  end
end
