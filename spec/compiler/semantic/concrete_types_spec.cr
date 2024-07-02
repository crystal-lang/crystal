require "../../spec_helper"

private def assert_concrete_types(str, &)
  result = semantic("struct Witness;end\n\n#{str}")
  program = result.program

  type, expected_concrete_types = yield program.types, program

  if type.responds_to?(:concrete_types)
    Set.new(type.concrete_types).should eq(Set.new(expected_concrete_types))
  elsif type.is_a?(ModuleType) || type.is_a?(GenericModuleInstanceType)
    # Modules are not MultiType, we check only using the witness
  else
    fail "#{type} : #{type.class} does not responds to :concrete_types"
  end

  # We enforce that the same results are expected for a concrete types
  # with respect a union of Witness. See UnionType#each_concrete_type
  witness_type = program.types["Witness"]
  wrapped_union = program.union_of([witness_type] of Type + (type.is_a?(UnionType) ? type.union_types : [type] of Type)).as(UnionType)
  Set.new(wrapped_union.concrete_types).should eq(Set.new(expected_concrete_types).add(witness_type))
end

describe "Semantic: concrete_types" do
  it "UnionType of structs" do
    assert_concrete_types(%(
      struct Foo
      end

      struct Bar
      end
    )) do |t, p|
      {p.union_of(t["Foo"], t["Bar"]), [t["Foo"], t["Bar"]]}
    end
  end

  it "VirtualType with abstract base" do
    assert_concrete_types(%(
      abstract class Base
      end

      class Foo < Base
      end

      class Bar < Base
      end
    )) do |t|
      {t["Base"].virtual_type, [t["Foo"], t["Bar"]]}
    end
  end

  it "VirtualType with concrete base" do
    assert_concrete_types(%(
      class Base
      end

      class Foo < Base
      end

      class Bar < Base
      end
    )) do |t|
      {t["Base"].virtual_type, [t["Base"], t["Foo"], t["Bar"]]}
    end
  end

  it "VirtualMetaclassType with abstract base" do
    assert_concrete_types(%(
      abstract class Base
      end

      class Foo < Base
      end

      class Bar < Base
      end
    )) do |t|
      # abstract base class are required because the metaclass can always be used: Base.method
      {t["Base"].virtual_type.metaclass, [t["Base"].metaclass, t["Foo"].metaclass, t["Bar"].metaclass]}
    end
  end

  it "VirtualMetaclassType with concrete base" do
    assert_concrete_types(%(
      class Base
      end

      class Foo < Base
      end

      class Bar < Base
      end
    )) do |t|
      {t["Base"].virtual_type.metaclass, [t["Base"].metaclass, t["Foo"].metaclass, t["Bar"].metaclass]}
    end
  end

  it "ModuleType" do
    assert_concrete_types(%(
      module M
      end

      class Foo
        include M
      end

      class Bar
        include M
      end
    )) do |t|
      {t["M"], [t["Foo"], t["Bar"]]}
    end
  end

  it "GenericModuleInstanceType" do
    assert_concrete_types(%(
      module M(T)
      end

      class A
      end

      class B
      end

      class Q
      end

      class Foo
        include M(A)
      end

      class Bar
        include M(A)
      end

      class Baz
        include M(B)
      end

      # Q is used to so the remove_indirection has a GenericModuleInstanceType
      alias Anchor = M(A) | Q
    )) do |t, p|
      {t["Anchor"].remove_indirection, [t["Q"], t["Foo"], t["Bar"]]}
    end
  end
end
