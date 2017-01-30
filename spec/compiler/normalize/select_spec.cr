require "../../spec_helper"

describe "Normalize: case" do
  it "normalizes select with call" do
    assert_expand "select; when foo; body; when bar; baz; end", <<-CODE
      __temp_1, __temp_2 = ::Channel.select({foo_select_action, bar_select_action})
      case __temp_1
      when 0
        body
      when 1
        baz
      else
        ::raise("BUG: invalid select index")
      end
      CODE
  end

  it "normalizes select with assign" do
    assert_expand "select; when x = foo; x + 1; end", <<-CODE
      __temp_1, __temp_2 = ::Channel.select({foo_select_action})
      case __temp_1
      when 0
        x = __temp_2.as(typeof(foo))
        x + 1
      else
        ::raise("BUG: invalid select index")
      end
      CODE
  end

  it "normalizes select with else" do
    assert_expand "select; when foo; body; else; baz; end", <<-CODE
      __temp_1, __temp_2 = ::Channel.select({foo_select_action}, true)
      case __temp_1
      when 0
        body
      else
        baz
      end
      CODE
  end

  it "normalizes select with assign and question method" do
    assert_expand "select; when x = foo?; x + 1; end", <<-CODE
      __temp_1, __temp_2 = ::Channel.select({foo_select_action?})
      case __temp_1
      when 0
        x = __temp_2.as(typeof(foo?))
        x + 1
      else
        ::raise("BUG: invalid select index")
      end
      CODE
  end

  it "normalizes select with assign and bang method" do
    assert_expand "select; when x = foo!; x + 1; end", <<-CODE
      __temp_1, __temp_2 = ::Channel.select({foo_select_action!})
      case __temp_1
      when 0
        x = __temp_2.as(typeof(foo!))
        x + 1
      else
        ::raise("BUG: invalid select index")
      end
      CODE
  end
end
