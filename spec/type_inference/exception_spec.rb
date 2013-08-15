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

  it "type union with empty main block" do
    assert_type(%(
      begin
      rescue
        1
      end
    )) { union_of(self.nil, int32) }
  end

  it "type union with empty rescue block" do
    assert_type(%(
      begin
        1
      rescue
      end
    )) { union_of(self.nil, int32) }
  end

  it "type for exception handler for explicit types" do
    assert_type(%(
      require "prelude"

      class MyEx < Exception
      end

      begin
        raise MyEx.new
      rescue MyEx
        1
      end
    )) { int32 }
  end

  it "marks #{Program::RAISE_NAME} as raises" do
    mod, type = assert_type(%(require "prelude"; 1)) { int32 }
    a_def = mod.lookup_first_def(Program::RAISE_NAME, false)
    a_def.raises.should be_true
  end

  it "marks #{Program::MAIN_NAME} as raises" do
    mod, type = assert_type(%(lib Crystal; fun #{Program::MAIN_NAME}; end; 1)) { int32 }
    a_def = mod.types["Crystal"].lookup_first_def(Program::MAIN_NAME, false)
    a_def.raises.should be_true
  end

  it "marks method calling method that raises as raises" do
    mod, type = assert_type(%Q(
      require "prelude"
      def foo
        #{Program::RAISE_NAME}(ABI::UnwindException.new)
      end
      foo
    )) { no_return }
    a_def = mod.lookup_first_def("foo", false)
    def_instance = mod.lookup_def_instance(a_def.object_id, [], nil)
    def_instance.raises.should be_true
  end

  it "types exception var with no types" do
    assert_type(%Q(
      a = nil
      begin
      rescue => ex
        a = ex
      end
      a
    )) { union_of(self.nil, exception.hierarchy_type) }
  end

  it "types exception with type" do
    assert_type(%Q(
      class Ex < Exception
      end

      a = nil
      begin
      rescue Ex => ex
        a = ex
      end
      a
    )) { union_of(self.nil, types["Ex"].hierarchy_type) }
  end

  it "errors if exception var shadows local var" do
    assert_syntax_error "ex = 1; begin; rescue => ex; end", "exception variable 'ex' shadows local variable 'ex'"
  end

  it "errors if catched exception is not a subclass of Exception" do
    assert_error "begin; rescue Int32 => ex; end", "Int32 is not a subclass of Exception"
  end

  it "errors if catched exception is not a subclass of Exception without var" do
    assert_error "begin; rescue Int32; end", "Int32 is not a subclass of Exception"
  end
end
