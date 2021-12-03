module Prairie
  class Result
    attr_reader :stacktrace

    def initialize(stacktrace = [])
      @stacktrace = stacktrace
    end

    def add_stacktrace(path:, cname:, mname:)
      if stacktrace.any?{|s| s.path == path && s.mname == mname}
        return false
      else
        stacktrace << ResultLine.new(path: path, cname: cname, mname: mname)
        return true
      end
    end

    def deep_dup
      Result.new(stacktrace.deep_dup)
    end

    def to_s
      stacktrace.each(&:to_s).joins('\n' + ' ')
    end

    def pretty_print(p)
      p.group(1, '#<Prairie::Result>') {
        p.breakable
        p.text ' '*2 # なんか揃わん
        p.group(2) {
          p.seplist(stacktrace) {|v| p.pp v}
        }
      }
    end

    class ResultLine
      attr_accessor :path, :cname, :mname
      def initialize(path:, cname:, mname:)
        @path = path
        @cname = cname
        @mname = mname
      end

      def to_s
        "#{path} #{cname}##{mname}"
      end

      def pretty_print(p)
        p.text self.to_s
      end
    end
  end
end
