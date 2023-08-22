module Crystal
  module Annotatable
    # Annotations on this instance
    property annotations : Hash(AnnotationType, Array(Annotation))?

    # Adds an annotation with the given type and value
    def add_annotation(annotation_type : AnnotationType, value : Annotation)
      annotations = @annotations ||= {} of AnnotationType => Array(Annotation)
      annotations[annotation_type] ||= [] of Annotation
      annotations[annotation_type] << value
    end

    # Returns the last defined annotation with the given type, if any, or `nil` otherwise
    def annotation(annotation_type : AnnotationType) : Annotation?
      @annotations.try &.[annotation_type]?.try &.last?
    end

    # Returns all annotations with the given type, if any, or `nil` otherwise
    def annotations(annotation_type : AnnotationType) : Array(Annotation)?
      @annotations.try &.[annotation_type]?
    end

    # Returns all annotations on this type, if any, or `nil` otherwise
    def all_annotations : Array(Annotation)?
      @annotations.try &.values.flatten
    end
  end
end
