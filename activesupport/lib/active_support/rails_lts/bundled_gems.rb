# Rails LTS: Ruby keeps moving parts of its standard library out into bundled
# gems — base64 and bigdecimal in 3.4, logger and benchmark in 4.0, and so on.
# A bundled gem is still installed with Ruby, but under Bundler it can only be
# required if the Gemfile asks for it, so an application that used to work
# suddenly dies on `require 'logger'`.
#
# Rails 2.3 requires a fair number of these, often from deep inside the stack
# where the raw LoadError says nothing about what to do. So each framework
# checks up front for the ones it needs and says which gems to add.

module RailsLts
  module Support
    module Ruby
      # Requires each of the given features, and reports the ones Ruby no longer
      # ships in a single actionable message. Only pass features whose gem name
      # matches the name you require.
      def self.require_bundled_gems(*features)
        missing = []
        features.each do |feature|
          begin
            require feature
          rescue LoadError
            missing << feature
          end
        end
        return if missing.empty?

        if missing.length == 1
          fail LoadError, "Ruby #{RUBY_VERSION} no longer ships #{missing.first} as part of its " \
                          "standard library. Please add \"gem '#{missing.first}'\" to your Gemfile."
        else
          lines = missing.map { |feature| "  gem '#{feature}'" }.join("\n")
          fail LoadError, "Ruby #{RUBY_VERSION} no longer ships these as part of its standard " \
                          "library: #{missing.join(', ')}. Please add them to your Gemfile:\n#{lines}"
        end
      end
    end
  end
end
