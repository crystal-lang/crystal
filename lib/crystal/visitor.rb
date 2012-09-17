module Crystal
  class Visitor
    [
      'module',
      'expressions',
      'array',
      'bool',
      'int',
      'float',
      'char',
      'def',
      'var',
      'call',
      'if',
      'class_def',
      'assign',
      'while',
      'nil',
      'block',
      'yield',
      'return',
      'next',
      'break',
    ].each do |name|
      class_eval %Q(
        def visit_#{name}(node)
          true
        end

        def end_visit_#{name}(node)
        end
      )
    end
  end
end
