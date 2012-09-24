require 'spec_helper'

describe 'Type inference: class' do
	it "types Const#new" do
		input = parse "class Foo; end; Foo.new"
		mod = infer_type input
		input.last.type.should eq(mod.types['Foo'])
	end

	it "types Const#new" do
		input = parse "class Foo; def coco; 1; end; end; Foo.new.coco"
		mod = infer_type input
		input.last.type.should eq(mod.int)
	end

	it "types instance variable" do
		input = parse %(
			class Foo
				def set
					@coco = 2
				end
				
				def get
					@coco
				end
			end

			f = Foo.new
			f.set
			f.get
		)
		mod = infer_type input
		input[1].type.should eq(ObjectType.new("Foo").with_var("@coco", mod.int))
	end
end
