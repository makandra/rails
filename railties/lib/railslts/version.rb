module RailsLts
  module VERSION
    # Because of the we way we're requiring this files in .gemspecs,
    # it might be loaded multiple times when installing over Git.
    unless defined?(STRING)

      MAJOR = 2
      MINOR = 3
      TINY = 18
      LTS = 63
      STRING = [MAJOR, MINOR, TINY, LTS].join('.')

      def self.to_s
        STRING
      end

    end
  end
end
