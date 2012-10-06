# output: 24

def fact(n)
  if n <= 1
    1
  else
    n * fact(n - 1)
  end
end

putn fact(4)