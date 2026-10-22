# Tests use process parallelism, so these temporary method replacements stay local.
module McpMethodReplacement
  def with_method_result(target, name, result)
    original = target.method(name)
    target.define_singleton_method(name) { |*| result }
    yield
  ensure
    target.define_singleton_method(name, original)
  end
end
