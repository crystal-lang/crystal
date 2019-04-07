# DEPRECATED: `SemanticVersion` has been deprecated. Use `SoftwareVersion` instead.
{% if compare_versions(Crystal::VERSION, "0.28.0-0") >= 0 %}
@[Deprecated("Use SoftwareVersion instead.")]
{% end %}
alias SemanticVersion = SoftwareVersion
