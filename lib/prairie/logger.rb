require 'logger'
require 'io/console/size'

module Prairie
  class Logger
    @logger = ::Logger.new(STDOUT)
    @bar_max_width = [[IO.console_size[1], 120].min - 10, 0].max # 横に出る数字分雑に引く. 幅が足りなかったら0
    @max_progress = 0
    @current_progress = 0

    class << self

      def info(message)
        @logger.info("[PryTracer] " + message)
      end

      def start_progressbar(max_progress)
        @max_progress = max_progress
        print "0%"
      end

      def progress
        @current_progress = @current_progress + 1
        # 表示できない設定なら skip
        return if [@bar_max_width, @max_progress].min <= 0
        percent = @current_progress * 100 / @max_progress
        bar_str = '=' * (@bar_max_width * percent / 100)
        print "\r#{bar_str} #{percent}%"
      end

      def finish_progressbar
        if @current_progress != @max_progress
          print "\r#{'=' * @bar_max_width} #{100}%"
        end
        @max_progress = 0
        @current_progress = 0
        print "\n"
      end
    end
  end
end
