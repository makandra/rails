# frozen_string_literal: true

# Rails LTS: Ruby keeps moving parts of its standard library out into bundled
# gems -- base64, bigdecimal and mutex_m in 3.4, logger, benchmark and irb in
# 4.0, and so on. A bundled gem is still installed with Ruby, but under Bundler
# it can only be required if the Gemfile asks for it, so an application that
# used to work suddenly dies on `require 'logger'`, often from deep inside the
# stack, where the raw LoadError says nothing about what to do.
#
# So the places in Rails that require one of these go through this helper, which
# says which gems to add. On Rubies that still ship them, it is a plain require.
#
# Identical in every Rails LTS version that has it; it has to parse on Ruby 1.8.7
# and stay ASCII-only (Ruby 1.9 reads source files as US-ASCII).

module RailsLts
  module Support
    module Ruby
      # A LoadError, so that code rescuing LoadError for an optional library
      # keeps working, but one that code like rails/all can tell apart from the
      # library simply not being installed.
      class MissingBundledGem < LoadError
      end

      # Requires each of the given features, and reports the ones Ruby no longer
      # ships in a single actionable message. Only pass features whose gem name
      # matches the name you require.
      def self.require_bundled_gems(*features)
        missing = []
        features.each do |feature|
          begin
            require feature
          rescue LoadError => e
            # None of the features we check left the standard library before
            # Ruby 3.4, so on older Rubies a LoadError means something else is
            # wrong (a distro Ruby with irb split out, say) and is not ours to
            # explain.
            raise if RUBY_VERSION < '3.4'
            # Only the feature itself being missing is ours to explain, not
            # something the gem requires, or an extension that fails to load.
            # LoadError#path can be nil.
            raise if e.path && e.path != feature
            missing << feature
          end
        end
        return if missing.empty?

        if missing.length == 1
          error = MissingBundledGem.new("Ruby #{RUBY_VERSION} no longer ships #{missing.first} as part of its " \
                                        "standard library. Please add \"gem '#{missing.first}'\" to your Gemfile.")
          # Like the LoadError it replaces, so code checking LoadError#path still matches.
          error.instance_variable_set(:@path, missing.first)
        else
          lines = missing.map { |feature| "  gem '#{feature}'" }.join("\n")
          error = MissingBundledGem.new("Ruby #{RUBY_VERSION} no longer ships these as part of its standard " \
                                        "library: #{missing.join(', ')}. Please add them to your Gemfile:\n#{lines}")
        end
        raise error
      end
    end
  end
end
