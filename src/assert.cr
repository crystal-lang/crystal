macro assert_responds_to(var, method)"
  if #{var}.responds_to?(:#{method})
    #{var}
  else
    raise \"expected #{var} to respond to :#{method}, not \#{#{var}}\"
  end
"end
