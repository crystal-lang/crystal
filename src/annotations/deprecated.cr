# This annotations marks methods, types or constants as deprecated.
#
# It receives a `StringLiteral` as single argument containing a deprecation notice.
#
# ```cr
# @[Deprecated("#foo has been deprecated, use #bar instead")]
# def foo
# end
# ```
annotation Deprecated
end
