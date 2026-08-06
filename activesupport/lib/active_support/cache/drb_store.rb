module ActiveSupport
  module Cache
    class DRbStore < MemoryStore #:nodoc:
      attr_reader :address

      def initialize(address = 'druby://localhost:9192')
        # Rails LTS: only this cache store needs drb, so it is not in the check
        # ActiveSupport runs at load time.
        ActiveSupport::Ruby.require_bundled_gems('drb') unless defined?(DRbObject)
        super()
        @address = address
        @data = DRbObject.new(nil, address)
      end
    end
  end
end
