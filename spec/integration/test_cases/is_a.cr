# output: B
class T; end

class A < T; end

class B < T; end

t = A.new
t = nil
t = 1
t = B.new

def x(c)
end

problem = t.is_a?(T) ? t : 1
x(problem.class)
