def assert_type(str)
  input = Parser.parse str
  mod = infer_type input
  expected_type = yield mod
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
end
