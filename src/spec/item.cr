module Spec
  # :nodoc:
  #
  # Info that `describe`, `context` and `it` all have in common.
  module Item
    getter parent : Context
    getter description : String
    getter file : String
    getter line : Int32
    getter end_line : Int32
    getter? focus : Bool
  end
end
