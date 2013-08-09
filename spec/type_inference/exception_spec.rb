require 'spec_helper'

describe 'Type inference: exception' do
  it "type is union of main and rescue blocks" do
    assert_type(%(
      begin
        1
      rescue
        'a'
      end
    )) { union_of(int32, char) }
  end

  it "marks __crystal_raise as raises" do
    mod, type = assert_type(%(require "prelude"; 1)) { int32 }
    a_def = mod.lookup_first_def('__crystal_raise', false)
    a_def.raises.should be_true
  end

  it "marks method calling method that raises as raises" do
    mod, type = assert_type(%q(
      require "prelude"
      def foo
        __crystal_raise
      end
      foo
    )) { no_return }
    a_def = mod.lookup_first_def("foo", false)
    def_instance = mod.lookup_def_instance(a_def.object_id, [], nil)
    def_instance.raises.should be_true
  end
end
