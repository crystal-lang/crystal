require "../spec_helper"

describe "Crystal.once" do
  pending_wasm32 "doesn't allow returning from the block", tags: %w[slow] do
    assert_compile_error <<-CRYSTAL, "can't return from captured block"
      require "prelude"

      def init(flag : Bool*) : Nil
        Crystal.once(flag) { return }
      end

      flag = false
      init(pointerof(flag))
      CRYSTAL
  end
end
