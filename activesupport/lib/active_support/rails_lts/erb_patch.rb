require 'erb'

class ERB

  # CVE-2026-41316: def_method/def_module/def_class bypass @_init deserialization guard
  # https://www.ruby-lang.org/en/news/2026/04/21/erb-cve-2026-41316/
  rails_lts_erb_patched = ERB.const_defined?(:VERSION) && [
    '~> 4.0.3.1',
    '~> 4.0.4.1',
    '~> 6.0.1.1',
    '>= 6.0.4',
  ].any? { |req| Gem::Requirement.new(req).satisfied_by?(Gem::Version.new(ERB.const_get(:VERSION))) }

  unless rails_lts_erb_patched
    if RUBY_VERSION >= '2.0'
      # We should not use `alias_method` here, since if mixed with
      # `prepend` that creates an infinite loop.
      prepend(Module.new do
        def initialize(*args, &block)
          super
          @_init = self.class.singleton_class
        end
        ruby2_keywords :initialize if respond_to?(:ruby2_keywords, true)

        def result(*args, &block)
          unless @_init.equal?(self.class.singleton_class)
            raise ArgumentError, "not initialized"
          end
          super
        end
        ruby2_keywords :result if respond_to?(:ruby2_keywords, true)

        def def_method(*args, &block)
          unless @_init.equal?(self.class.singleton_class)
            raise ArgumentError, "not initialized"
          end
          super
        end
        ruby2_keywords :def_method if respond_to?(:ruby2_keywords, true)
      end)
    else
      # Ruby < 2 does not support `prepend`.

      alias_method :rails_lts_erb_initialize_without_cve_2026_41316, :initialize
      def initialize(*args, &block)
        rails_lts_erb_initialize_without_cve_2026_41316(*args, &block)
        @_init = self.class.singleton_class
      end

      alias_method :rails_lts_erb_result_without_cve_2026_41316, :result
      def result(*args, &block)
        unless @_init.equal?(self.class.singleton_class)
          raise ArgumentError, "not initialized"
        end
        rails_lts_erb_result_without_cve_2026_41316(*args, &block)
      end

      alias_method :rails_lts_erb_def_method_without_cve_2026_41316, :def_method
      def def_method(*args, &block)
        unless @_init.equal?(self.class.singleton_class)
          raise ArgumentError, "not initialized"
        end
        rails_lts_erb_def_method_without_cve_2026_41316(*args, &block)
      end
    end
  end

end
