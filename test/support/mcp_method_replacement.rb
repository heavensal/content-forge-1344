module McpMethodReplacement
  def with_method_result(target, name, result)
    with_method_override(target, name, ->(*) { result }) { yield }
  end

  def with_method_override(target, name, implementation, &block)
    singleton = target.singleton_class
    original = singleton.instance_method(name)
    was_private = singleton.private_instance_methods(false).include?(name)
    singleton.send(:define_method, name, implementation)
    yield
  ensure
    singleton.send(:define_method, name, original)
    singleton.send(:private, name) if was_private
  end
end
