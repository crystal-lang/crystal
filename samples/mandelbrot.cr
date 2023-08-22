def print_density(d)
  if d > 8
    print ' '
  elsif d > 4
    print '.'
  elsif d > 2
    print '*'
  else
    print '+'
  end
end

def mandelconverger(real, imag, iters, creal, cimag)
  if iters > 255 || real*real + imag*imag >= 4
    iters
  else
    mandelconverger real*real - imag*imag + creal, 2*real*imag + cimag, iters + 1, creal, cimag
  end
end

def mandelconverge(real, imag)
  mandelconverger real, imag, 0, real, imag
end

def mandelhelp(xmin, xmax, xstep, ymin, ymax, ystep)
  ymin.step(to: ymax, by: ystep) do |y|
    xmin.step(to: xmax, by: xstep) do |x|
      print_density mandelconverge(x, y)
    end
    puts
  end
end

def mandel(realstart, imagstart, realmag, imagmag)
  mandelhelp realstart, realstart + realmag*78, realmag, imagstart, imagstart + imagmag*40, imagmag
end

mandel -2.3, -1.3, 0.05, 0.07
