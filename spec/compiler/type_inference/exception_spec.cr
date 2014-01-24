#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: exception" do
  it "type is union of main and rescue blocks" do
    assert_type("
      begin
        1
      rescue
        'a'
      end
    ") { union_of(int32, char) }
  end

  it "type union with empty main block" do
    assert_type("
      begin
      rescue
        1
      end
    ") { |mod| union_of(mod.nil, int32) }
  end

  it "type union with empty rescue block" do
    assert_type("
      begin
        1
      rescue
      end
    ") { |mod| union_of(mod.nil, int32) }
  end

  it "type for exception handler for explicit types" do
    assert_type("
      require \"prelude\"

      class MyEx < Exception
      end

      begin
        raise MyEx.new
      rescue MyEx
        1
      end
    ") { int32 }
  end

  it "marks #{Crystal::RAISE_NAME} as raises" do
    result = assert_type("fun #{Crystal::RAISE_NAME} : Int32; 1; end; 1") { int32 }
    mod = result.program
    a_def = mod.lookup_first_def(Crystal::RAISE_NAME, false)
    a_def.not_nil!.raises.should be_true
  end

  it "marks #{Crystal::MAIN_NAME} as raises" do
    result = assert_type("lib CrystalMain; fun #{Crystal::MAIN_NAME}; end; 1") { int32 }
    mod = result.program
    a_def = mod.types["CrystalMain"].lookup_first_def(Crystal::MAIN_NAME, false)
    a_def.not_nil!.raises.should be_true
  end

  it "marks method calling method that raises as raises" do
    result = assert_type("
      fun #{Crystal::RAISE_NAME} : Int32; 1; end
      def foo
        #{Crystal::RAISE_NAME}
      end
      foo
    ") { int32 }
    mod = result.program
    a_def = mod.lookup_first_def("foo", false)
    def_instance = mod.lookup_def_instance(a_def.object_id, ([] of Type), nil)
    def_instance.not_nil!.raises.should be_true
  end

  it "types exception var with no types" do
    assert_type("
      a = nil
      begin
      rescue ex
        a = ex
      end
      a
    ") { |mod| union_of(mod.nil, exception.hierarchy_type) }
  end

  it "types exception with type" do
    assert_type("
      class Ex < Exception
      end

      a = nil
      begin
      rescue ex : Ex
        a = ex
      end
      a
    ") { |mod| union_of(mod.nil, types["Ex"].hierarchy_type) }
  end

  it "errors if exception var shadows local var" do
    assert_syntax_error "ex = 1; begin; rescue ex; end", "exception variable 'ex' shadows local variable 'ex'"
  end

  it "errors if catched exception is not a subclass of Exception" do
    assert_error "begin; rescue ex : Int32; end", "Int32 is not a subclass of Exception"
  end

  it "errors if catched exception is not a subclass of Exception without var" do
    assert_error "begin; rescue Int32; end", "Int32 is not a subclass of Exception"
  end

  it "errors if exception varaible is used after rescue" do
    assert_error "begin; rescue ex; end; ex", "undefined local variable or method 'ex'"
  end

  it "errors if catch-all rescue before specific rescue" do
    assert_syntax_error "begin; rescue ex; rescue ex : Foo; end; ex", "specific rescue must come before catch-all rescue"
  end

  it "errors if catch-all rescue specified twice" do
    assert_syntax_error "begin; rescue ex; rescue; end; ex", "catch-all rescue can only be specified once"
  end

  it "errors if else without rescue" do
    assert_syntax_error "begin; else; 1; end", "'else' is useless without 'rescue'"
  end
end
