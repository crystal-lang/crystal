{% skip_file unless flag?(:win32) %}
require "registry"
require "spec"

private TEST_RAND = Random.rand(0x100000000).to_s(36)

private def test_key(prefix = "TestKey", sam = Registry::SAM::ALL_ACCESS)
  name = "Crystal\\#{prefix}_#{TEST_RAND}"
  Registry::CURRENT_USER.open("Software", Registry::SAM::QUERY_VALUE) do |parent|
    begin
      parent.create_key?(name)
      parent.open(name, sam) do |key|
        yield key
      end
    ensure
      parent.delete_key?(name)
    end
  end
end

private def assert_set_get(name, value, type = nil)
  it name do
    test_key do |key|
      if valtype = type
        key.set(name, value, valtype)
      else
        key.set(name, value)
      end
      key.get(name).should eq value
      key.get?(name).should eq value
    end
  end
end

private def assert_set_exception(name, value, type = nil, error_message = "String contains null byte", file = __FILE__, line = __LINE__)
  it "#{name} fails null byte check", file, line do
    test_key do |key|
      expect_raises(ArgumentError, error_message) do
        if valtype = type
          key.set(name, value, valtype)
        else
          key.set(name, value)
        end
      end
    end
  end
end

describe Registry::Key do
  describe "#each_key" do
    it "lists keys" do
      test_key do |key|
        key.create_key "EachKeySub1"
        key.create_key "EachKeySub2"
        subkeys = [] of String
        key.each_key do |subkey|
          subkeys << subkey
        end
        subkeys.should eq ["EachKeySub1", "EachKeySub2"]
        key.subkeys.should eq ["EachKeySub1", "EachKeySub2"]
      end
    end

    it "finds standard key" do
      Registry::CLASSES_ROOT.open("TypeLib", Registry::SAM::ENUMERATE_SUB_KEYS | Registry::SAM::QUERY_VALUE) do |key|
        foundStdOle = false
        key.each_key do |name|
          # Every PC has "stdole 2.0 OLE Automation" library installed.
          if name == "{00020430-0000-0000-C000-000000000046}"
            foundStdOle = true
          end
        end
        foundStdOle.should be_true
      end
    end
  end

  it "create, open, delete key" do
    Registry::CURRENT_USER.open("Software", Registry::SAM::QUERY_VALUE) do |software|
      test_key = "TestCreateOpenDeleteKey_#{Random.rand(0x100000000).to_s(36)}"

      software.create_key(test_key, Registry::SAM::CREATE_SUB_KEY)
      software.create_key?(test_key, Registry::SAM::CREATE_SUB_KEY).should be_false

      software.open(test_key, Registry::SAM::ENUMERATE_SUB_KEYS) { |test| }

      software.delete_key?(test_key)
      software.delete_key?(test_key)

      software.open?(test_key, Registry::SAM::ENUMERATE_SUB_KEYS).should be_nil
    end
  end

  describe "values" do
    it "unset value" do
      test_key do |key|
        expect_raises(Registry::Error, %(Value "non-existing" does not exist)) do
          key.get("non-existing")
        end
      end
    end

    describe "SZ" do
      assert_set_get("String1", "")
      assert_set_exception("String2", "\0", error_message: "String `value` contains null byte")
      assert_set_get("String3", "Hello World")
      assert_set_exception("String4", "Hello World\0", error_message: "String `value` contains null byte")
      assert_set_get("StringLong", "a" * 257)
    end

    describe "EXPAND_SZ" do
      assert_set_get("ExpString1", "", type: Registry::ValueType::EXPAND_SZ)
      assert_set_exception("ExpString2", "\0", error_message: "String `value` contains null byte", type: Registry::ValueType::EXPAND_SZ)
      assert_set_get("ExpString3", "Hello World")
      assert_set_exception("ExpString4", "Hello\0World", error_message: "String `value` contains null byte", type: Registry::ValueType::EXPAND_SZ)
      assert_set_get("ExpString6", "%NO_SUCH_VARIABLE%", type: Registry::ValueType::EXPAND_SZ)
      assert_set_get("ExpStringLong", "a" * 257, type: Registry::ValueType::EXPAND_SZ)

      it "expands single env var" do
        test_key do |key|
          key.set("ExpString5", "%PATH%", Registry::ValueType::EXPAND_SZ)
          key.get("ExpString5").should eq(ENV["PATH"])
          key.get?("ExpString5").should eq(ENV["PATH"])
        end
      end

      it "expands env var in string" do
        test_key do |key|
          key.set("ExpString7", "%PATH%;.", Registry::ValueType::EXPAND_SZ)
          key.get("ExpString7").should eq(ENV["PATH"] + ";.")
          key.get?("ExpString7").should eq(ENV["PATH"] + ";.")
        end
      end
    end

    describe "BINARY" do
      assert_set_get("Binary1", Bytes.new(0))
      assert_set_get("Binary2", StaticArray[1_u8, 2_u8, 3_u8].to_slice)
      assert_set_get("Binary3", StaticArray[3_u8, 2_u8, 1_u8, 0_u8, 1_u8, 2_u8, 3_u8].to_slice)
      assert_set_get("BinaryLarge", Bytes.new(257, 1_u8))
    end

    describe "DWORD" do
      assert_set_get("Dword1", 0)
      assert_set_get("Dword2", 1)
      assert_set_get("Dword3", 0xff)
      assert_set_get("Dword4", 0xffff)
    end

    describe "QWORD" do
      assert_set_get("Qword1", 0_i64)
      assert_set_get("Qword2", 1_i64)

      assert_set_get("Qword3", 0xff_i64)
      assert_set_get("Qword4", 0xffff_i64)
      assert_set_get("Qword5", 0xffffff_i64)
      assert_set_get("Qword6", 0xffffffff_i64)
    end

    describe "MULTI_SZ" do
      assert_set_get("MultiString1", ["a", "b", "c"])
      assert_set_get("MultiString2", ["abc", "", "cba"])
      assert_set_get("MultiString3", [""])
      assert_set_get("MultiString4", ["abcdef"])
      assert_set_exception("MultiString5", ["\000"])
      assert_set_exception("MultiString6", ["a\000b"])
      assert_set_exception("MultiString7", ["ab", "\000", "cd"])
      assert_set_exception("MultiString8", ["\000", "cd"])
      assert_set_exception("MultiString9", ["ab", "\000"])
      assert_set_get("MultiStringLong", ["a" * 257])
    end
  end

  describe "#get_mui" do
    it "handles non-existing key" do
      test_key do |key|
        expect_raises(Registry::Error, "Value 'NonExistingMUI' does not exist") do
          key.get_mui("NonExistingMUI")
        end
        key.get_mui?("NonExistingMUI").should be_nil
      end
    end

    it "handles non-loadable value" do
      test_key do |key|
        key.set("InvalidMUI", "foo")
        expect_raises(WinError, "RegLoadMUIStringW: [WinError 13") do
          key.get_mui("InvalidMUI")
        end
        expect_raises(WinError, "RegLoadMUIStringW: [WinError 13") do
          key.get_mui?("InvalidMUI")
        end
      end
    end

    it "loads timezone name" do
      LibC.GetDynamicTimeZoneInformation(out dtz_info).should_not eq(0)

      key_name = String.from_utf16(dtz_info.timeZoneKeyName.to_unsafe)[0]

      Registry::LOCAL_MACHINE.open("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones\\#{key_name}", Registry::SAM::READ) do |key|
        key.get_mui("MUI_Std").should eq(String.from_utf16(dtz_info.standardName.to_unsafe)[0])
        key.get_mui?("MUI_Std").should eq(String.from_utf16(dtz_info.standardName.to_unsafe)[0])
        if dtz_info.dynamicDaylightTimeDisabled == 0
          key.get_mui("MUI_Dlt").should eq(String.from_utf16(dtz_info.daylightName.to_unsafe)[0])
          key.get_mui?("MUI_Dlt").should eq(String.from_utf16(dtz_info.daylightName.to_unsafe)[0])
        end
      end
    end
  end

  it "#get_string" do
    test_key do |key|
      key.set("test_string", "foo bar")
      key.get_string("test_string").should eq "foo bar"

      expect_raises(Registry::Error, %(Value "non-existant" does not exist)) do
        key.get_string("non-existant")
      end
    end
  end

  it "#get_string?" do
    test_key do |key|
      key.set("test_string", "foo bar")
      key.get_string?("test_string").should eq "foo bar"
      key.get_string?("non-existant").should be_nil
    end
  end

  describe "#info" do
    it do
      test_key("TestInfo") do |test|
        test.info.sub_key_count.should eq 0
        test.create_key("subkey")
        test.info.sub_key_count.should eq 1
        test.info.max_sub_key_length.should eq "subkey".size

        test.set("f", "quux")
        test.set("foo", "bar baz")
        info = test.info
        info.value_count.should eq 2
        info.max_value_name_length.should eq "foo".size
        info.max_value_length.should eq "bar baz".to_utf16.bytesize + 2
      ensure
        test.delete_key("subkey")
      end
    end
  end
end
