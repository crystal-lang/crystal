require "../../spec_helper"

describe "Hierarchy-dependent inference" do
  {
    "as"          => "value.as(Good).value",
    "as?"         => "if narrowed = value.as?(Good); narrowed.value; else; 0; end",
    "restriction" => "extract(value)",
  }.each do |operation, body|
    it "updates #{operation} in a cached method when the source hierarchy grows" do
      assert_type(<<-CRYSTAL) { union_of(int32, int64) }
        abstract class Base(T)
        end

        class Good(T, U) < Base(T)
          def value
            result = uninitialized U
            result
          end
        end

        def extract(value : Good)
          value.value
        end

        def foo(value : Base(Int32))
          #{body}
        end

        foo(Good(Int32, Int32).new.as(Base(Int32)))
        foo(Good(Int32, Int64).new.as(Base(Int32)))
        CRYSTAL
    end
  end

  it "observes every member of a union argument's hierarchies" do
    assert_type(<<-CRYSTAL) { union_of(int32, int64) }
      abstract class Base(T)
      end

      class Good(T, U) < Base(T)
        def value
          result = uninitialized U
          result
        end
      end

      def extract(value : Good)
        value.value
      end

      def foo(value : Base(Int32) | Base(Char))
        extract(value)
      end

      foo(Good(Int32, Int32).new.as(Base(Int32) | Base(Char)))
      foo(Good(Char, Int64).new.as(Base(Int32) | Base(Char)))
      CRYSTAL
  end
end
