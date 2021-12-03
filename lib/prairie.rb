require 'active_support/all'

require 'prairie/version'
require 'prairie/extend_pry'
require 'prairie/tracer'

module Prairie
  class << self
    def setup
      Prairie::Tracer.setup
    end

    def overlook(class_name)
      Prairie::Tracer.search(class_name)
    end
  end
end
