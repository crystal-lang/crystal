# NOTE: This type might be removed.
# :nodoc:
struct Reflect(X)
  # For now it's just a way to implement `Enumerable#sum` in a way that the
  # initial value given to it has the type of the first type in the union,
  # if the type is a union.
  def self.first
    {% if X.union? %}
      {{X.union_types.first}}
    {% else %}
      X
    {% end %}
  end
end
