ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Placeholder fixtures are empty, and this database cannot disable foreign keys
    # during fixture deletes. Tests create the records they need.
    # fixtures :all

    # Add more helper methods to be used by all tests here...
    def stubbing(object, method_name, replacement)
      singleton = object.singleton_class
      backup = :"_stub_backup_#{method_name}_#{Process.pid}_#{stub_sequence}"
      singleton.alias_method(backup, method_name)
      singleton.define_method(method_name) do |*args, **kwargs, &block|
        next replacement unless replacement.respond_to?(:call)

        kwargs.empty? ? replacement.call(*args, &block) : replacement.call(*args, **kwargs, &block)
      end
      yield
    ensure
      singleton.alias_method(method_name, backup)
      singleton.remove_method(backup)
    end

    def stub_sequence
      @stub_sequence = @stub_sequence.to_i + 1
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
