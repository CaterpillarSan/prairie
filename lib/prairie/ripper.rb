require 'ripper'

module Prairie
  class Ripper
    attr_reader :constants

    def initialize
      @constants = []
    end

    def get_const_list(str)
      res = ::Ripper.sexp(str)
      # 例: def self.\#{sym}\n  @@\#{sym}\nend\n
      # TODO skip されたメソッド一覧を見られるようにしたい
      return constants if res.blank?
      if res[0] != :program
        raise
      end

      res[1].each do |tok|
        _parse(tok)
      end
      @constants = @constants.uniq
    end

    private

    def _parse(tok)
      return if tok.blank?
      if tok[0].is_a?(Array)
        tok.each do |t|
          _parse(t)
        end
      else
        key, *body = tok
        case key
        when :const_path_ref
          @constants << _parse_const_ref(body)
        when :@const
          @constants << body[0]
        else
          _parse(body)
        end
      end
    end

    def _parse_const_ref(tok)
      result = ''
      tok.each do |t|
        key, *body = t
        case key
        when :@const
          result << "::#{body[0]}"
        else
          result << "::#{_parse_const_ref(body)}"
        end
      end

      return result.gsub(/^::/, '')
    end
  end
end
