def putn(n)
  if n > 10
    putn(n / 10)
    putn(n - (n / 10) * 10)
  else
    putchar (n + '0'.ord).chr
  end
end
