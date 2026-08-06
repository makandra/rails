# Rails LTS: shared by every gem's test bootstrap.
#
# test-unit sets Warning[:deprecated] = true, and from Ruby 3.4 on that turns
# each mutation of a string literal into a warning. Rails 2.3 does that in a
# couple of hundred places, which drowned the Ruby 4 CI job in 16k lines and
# hid the test output.
#
# Ruby leaves deprecation warnings off by default, so an application running
# Rails LTS never sees these; they are an artifact of how we run our own tests.
# Set FROZEN_STRING_WARNINGS=1 to get them back when working through them.
#
# Everything else Ruby has to say still comes through.
if RUBY_VERSION >= '3.4' && ENV['FROZEN_STRING_WARNINGS'].to_s.empty?
  # eval'd because Ruby 1.8.7 cannot parse keyword arguments, and a plain
  # RUBY_VERSION check does not save us from a SyntaxError.
  #
  # An extended module rather than a reopened `module Warning`, so that super
  # still reaches Ruby's own implementation.
  eval(<<-RUBY, TOPLEVEL_BINDING)
    Warning.extend(Module.new do
      def warn(message, category: nil)
        return if message.include?('literal string will be frozen')
        super
      end
    end)
  RUBY
end
