module Akane
  module Util
    class << self
      def symbolish_hash(hash)
        Hash[hash.map { |k, v|
          [
            k.is_a?(Symbol) ? k : k.to_s.to_sym,
            case v
            when Hash; symbolish_hash(v)
            when Array; v.map{ |i| i.kind_of?(Hash) ? symbolish_hash(i) : i }
            else; v
            end
          ]
        }]
      end
    end
  end
end
