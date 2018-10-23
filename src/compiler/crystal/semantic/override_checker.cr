class Crystal::OverrideChecker
  def initialize(@program : Program)
    @all_checked = Set(Type).new
  end

  def run
    check_types(@program)
  end

  def check_types(type)
    type.types?.try &.each_value do |type|
      check_single(type)
    end
  end

  def check_single(type)
    return if @all_checked.includes?(type)
    @all_checked << type

    type.defs.try &.each_value do |defs_with_metadata|
      defs_with_metadata.each do |def_with_metadata|
        a_def = def_with_metadata.def
        if a_def.overrides?
          check_overrides(type, def_with_metadata)
        end
      end
    end

    check_types(type)
  end

  def check_overrides(type, def_with_metadata)
    found_def_with_same_name = false

    type.ancestors.each do |ancestor|
      other_defs_with_metadata = ancestor.defs.try &.[def_with_metadata.def.name]?
      other_defs_with_metadata.try &.each do |other_def_with_metadata|
        found_def_with_same_name = true

        if def_with_metadata.restriction_of?(other_def_with_metadata, type) ||
           other_def_with_metadata.restriction_of?(def_with_metadata, ancestor)
          # Found a method with the same name and same, stricter or weaker restriction,
          # so it overrides
          return
        end
      end
    end

    # Couldn't find a method
    msg = "method has Override annotation but doesn't override"
    if found_def_with_same_name
      msg += " (type restrictions don't match)"
    else
      msg += " (no such method)"
    end

    def_with_metadata.def.raise(msg)
  end
end
