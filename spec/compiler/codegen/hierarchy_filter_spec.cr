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
        # sizeof(Int32) = 4 and sizeof(Int64) = 8; encode both results as 48.
        (first &* 10) &+ second
        CRYSTAL
    end
  end

  it "keeps shared receiver and argument dependencies across union receiver lookup" do
    run(<<-CRYSTAL).to_i.should eq(48)
      module Base
        def read(value : Good)
          value.value
        end
      end

      module Other
        def read(value : Good)
          value.value
        end
      end

      class Good(T)
        include Base

        def value
          sizeof(T)
        end
      end

      class Alternate
        include Other
      end

      def foo(receiver : Base | Other, value : Base)
        receiver.read(value)
      end

      # Receiver dispatch and argument matching share the Base dependency.
      receiver = Good(Int32).new.as(Base | Other)
      first = foo(receiver, Good(Int32).new.as(Base))
      second = foo(receiver, Good(Int64).new.as(Base))
      (first &* 10) &+ second
      CRYSTAL
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
