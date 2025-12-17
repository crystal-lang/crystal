module Crystal
  # Types that can be used as annotation keys: traditional annotations or @[Annotation] classes
  alias AnnotationKey = AnnotationType | ClassType

  module Annotatable
    property annotations : Hash(AnnotationKey, Array(Annotation))?

    # Adds an annotation with the given type and value.
    # For @[Annotation] classes, validates repeatable and targets constraints.
    def add_annotation(annotation_type : AnnotationKey, value : Annotation, target : String? = nil)
      # Validation for @[Annotation] classes
      if annotation_type.is_a?(ClassType) && annotation_type.annotation_class?
        if metadata = annotation_type.annotation_metadata
          # Check for duplicate non-repeatable annotations
          if self.annotation(annotation_type) && !metadata.repeatable?
            value.raise "@[#{annotation_type}] cannot be repeated"
          end

          # Check target constraints
          if allowed = metadata.targets
            unless target && allowed.includes?(target)
              value.raise "@[#{annotation_type}] cannot target #{target} (allowed targets: #{allowed.join(", ")})"
            end
          end
        end
      end

      annotations = @annotations ||= {} of AnnotationKey => Array(Annotation)
      annotations[annotation_type] ||= [] of Annotation
      annotations[annotation_type] << value
    end

    # Returns the last defined annotation with the given type, if any, or `nil` otherwise.
    def annotation(annotation_type : AnnotationKey) : Annotation?
      @annotations.try &.[annotation_type]?.try &.last?
    end

    # Returns all annotations with the given type, if any, or `nil` otherwise.
    # If recursive is true, also returns annotations whose types inherit from or include annotation_type.
    def annotations(annotation_type : Type, recursive : Bool = false) : Array(Annotation)?
      results = [] of Annotation

      # Direct matches (only possible if type is an AnnotationKey)
      if annotation_type.is_a?(AnnotationKey)
        if direct = @annotations.try &.[annotation_type]?
          results.concat(direct)
        end
      end

      # Check for inheritance/inclusion if requested
      if recursive
        @annotations.try &.each do |stored_type, anns|
          next if stored_type == annotation_type
          if stored_type.is_a?(ClassType) && stored_type.annotation_class?
            if stored_type.ancestors.includes?(annotation_type)
              results.concat(anns)
            end
          end
        end
      end

      results.empty? ? nil : results
    end

    # Returns all annotations on this type, if any, or `nil` otherwise
    def all_annotations : Array(Annotation)?
      @annotations.try &.values.flatten
    end
  end
end
