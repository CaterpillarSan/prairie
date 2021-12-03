require 'pry'

class Pry
  class WrappedModule
    attr_accessor :object_type # [:model, :controller, :controller_concern, :service, :service_concern]
    # models: [wrapper, autosave, destroy]
    attr_accessor :models, :caller, :methods, :included_by

    def wrapped_initialize(mod)
      @models = []
      @caller = []
      @methods = {}
      @included_by = []

      original_initialize(mod)
    end

    alias :original_initialize :initialize
    alias :initialize :wrapped_initialize 

    def add_model(target, autosave, destroy)
      self.models << [target, autosave, destroy]
    end

    def add_method(name, const_list)
      self.methods[name] = const_list
    end

    def add_caller(target)
      self.caller << target
    end

    def add_included_by(target)
      self.included_by << target
    end

    def to_s
      "#<Pry::WrappedModule(#{self.name}) " +
      "@caller=#{caller.map(&:name)}, " +
      "@methods=#{methods}, " +
      "@included_by=#{included_by.map(&:name)}, " +
      "@models=#{models.map {|m| m[0].name }}" +
      '>'
    end

    def pretty_print(p)
      p.group(1, "#<WrappedModule(#{self.name}) ", '>') {
        p.group(2, '@caller=[', ']') { 
          p.seplist(caller.map(&:name)) {|v| p.pp v }
        }
        p.breakable

        p.group(2, '@methods=', '') { 
          p.pp methods
        }
        p.breakable

        p.group(2, '@included_by=[', ']') { 
          p.seplist(included_by.map(&:name)) {|v| p.pp v }
        }
        p.breakable

        p.group(2, '@models=[', ']') { 
          p.seplist(models.map{|m| m[0].name }) {|v| p.pp v }
        }
      }
    end
  end
end
