module Akane
  module Storages
    def self.find(name)
      class_name = name.gsub(/(?:\A|_)(.)/) { $1.upcase }

      retried = false
      begin
        return Akane::Storages.const_get(class_name, false)
      rescue NameError => e
        raise e if retried
        retried = true
        require "akane/storages/#{name}"
        retry
      end
    end
  end
end
