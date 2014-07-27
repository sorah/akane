module Akane
  module Receivers
    def self.find(name)
      class_name = name.gsub(/(?:\A|_)(.)/) { $1.upcase }

      retried = false
      begin
        return Akane::Receivers.const_get(class_name)
      rescue NameError => e
        raise e if retried
        retried = true
        require "akane/receivers/#{name}"
        retry
      end
    end
  end
end
