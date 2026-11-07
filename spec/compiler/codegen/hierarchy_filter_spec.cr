require "../../spec_helper"

describe "Code gen: hierarchy-dependent type filters" do
  {
    "is_a?"        => "if value.is_a?(Good); value.value; else; 0; end",
    "responds_to?" => "if value.responds_to?(:value); value.value; else; 0; end",
    "case"         => "case value; when Good; value.value; else; 0; end",
    "negation"     => "if !value.is_a?(Good); 0; else; value.value; end",
    "as?"          => "if narrowed = value.as?(Good); narrowed.value; else; 0; end",
    "restriction"  => "extract(value)",
    "named arg"    => "extract(value: value)",
    "splat"        => "extract(*{value})",
    "double splat" => "extract(**{value: value})",
  }.each do |operation, body|
    it "updates #{operation} narrowing in a cached method when the source hierarchy grows" do
      run(<<-CRYSTAL).to_i.should eq(48)
        abstract class Base(T)
        end

        class Good(T, U) < Base(T)
          def value
            sizeof(U)
          end
        end

        def extract(value : Good)
          value.value
        end

        def foo(value : Base(Int32))
          #{body}
        end

        first = foo(Good(Int32, Int32).new.as(Base(Int32)))
        second = foo(Good(Int32, Int64).new.as(Base(Int32)))
        (first &* 10) &+ second
        CRYSTAL
    end
  end

  it "updates narrowing in a cached method when a generic module gains including types" do
    run(<<-CRYSTAL).to_i.should eq(48)
      module Base(T)
      end

      class Good(T, U)
        include Base(T)

        def value
          sizeof(U)
        end
      end

      def foo(value : Base(Int32))
        if value.is_a?(Good)
          value.value
        else
          0
        end
      end

      first = foo(Good(Int32, Int32).new.as(Base(Int32)))
      second = foo(Good(Int32, Int64).new.as(Base(Int32)))
      (first &* 10) &+ second
      CRYSTAL
  end
end
