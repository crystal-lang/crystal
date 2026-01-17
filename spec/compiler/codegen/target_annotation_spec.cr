require "../spec_helper"

describe "Code gen: Target annotation" do
  it "errors if invalid Target argument provided" do
    assert_error <<-CRYSTAL, "invalid Target argument 'invalid'. Valid arguments are features, cpu"
      @[Target(invalid: "lorem ipsum")]
      def foo
      end
      CRYSTAL
  end
end
