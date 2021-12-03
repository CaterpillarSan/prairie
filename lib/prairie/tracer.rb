require 'prairie/logger'
require 'prairie/ripper'
require 'prairie/result'


module Prairie
  class Tracer
    cattr_accessor :objects, :excludes

    class << self
      def setup
        # TODO Rails オブジェクトがあるかなど
        return 'use in Rails.env.development' unless Rails.env.development?
        Prairie::Logger.info 'Start setup'
        self.excludes = []
        self.objects = {}
        Prairie::Logger.info 'Eager load Rails app'
        Rails.application.eager_load!

        load_models
        load_module(object_type: :service_concern, path: 'app/services/concerns/')
        load_module(object_type: :service, path: 'app/services/', reject_dir: 'concerns')
        load_module(object_type: :controller_concern, path: 'app/controllers/concerns')
        load_module(object_type: :controller, path: 'app/controllers/', reject_dir: 'concerns')
        # TODO その他ファイル
        link_modules
        Prairie::Logger.info 'Setup Succeed!'
      end

      def load_models
        Prairie::Logger.info 'Load model'
        results = {}
        model_classes = ActiveRecord::Base.descendants
        model_classes.each do |model|
          wm = Pry::WrappedModule(model)
          wm.object_type = :model
          results[model.name] = wm
        end

        # Relation の記録. TODO 別 method に出してもいい
        results.each do |name, wrap_model|
          wrap_model.wrapped.reflections.each do |other_model, reflection|
            options = reflection.options
            # TODO: 絶対 pathに変換必要?
            name = options[:class_name].presence || other_model.classify
            next unless results[name]
            results[name].add_model(wrap_model, options[:autosave], options[:destroy])
          end
        end

        # methods をこねる
        Prairie::Logger.start_progressbar(results.count)
        results.each do |_, wrap_obj|
          # TODO: 別ファイルのも欲しくなるかも
          wrap_obj.send(:all_relevant_methods_for, wrap_obj.wrapped).select {|m| m.source_file == wrap_obj.source_file }.each do |m|
            # TODO: スルーされた method わかるようにしたい?
            next unless m.source?
            wrap_obj.add_method(m.name, Prairie::Ripper.new.get_const_list(m.source))
          end
          Prairie::Logger.progress
        end
        Prairie::Logger.finish_progressbar
        self.objects.merge!(results)
      end

      def load_module(object_type:, path:, reject_dir: nil)
        Prairie::Logger.info "Load #{object_type}"
        results = {}
        # app/services/concern は以下のファイル全部
        filenames = Dir.glob('**/*.rb', base: path)
            .map {|fname| fname.gsub(/\.rb/, '') }
            .reject {|fname| reject_dir && fname.start_with?(reject_dir) }
        filenames.each do |fname|
          classname = fname.camelize
          wm = Pry::WrappedModule.from_str(classname)
          unless wm
            self.excludes << fname
            next
          end
          wm.object_type = object_type
          results[classname] = wm
        end

        # methods をこねる
        Prairie::Logger.start_progressbar(results.count)
        results.each do |_, wrap_obj|
          wrap_obj.send(:all_relevant_methods_for, wrap_obj.wrapped).select {|m| m.source_file == wrap_obj.source_file }.each do |m|
            # TODO: スルーされた method わかるようにしたい?
            wrap_obj.add_method(m.name, Prairie::Ripper.new.get_const_list(m.source))
          end
          Prairie::Logger.progress
        end
        Prairie::Logger.finish_progressbar
        self.objects.merge!(results)
      end

      def link_modules
        Prairie::Logger.info "Link modules"
        Prairie::Logger.start_progressbar(self.objects.count)
        self.objects.each do |name, wm|
          # include されている module を追加
          includes = wm.included_modules.select{|m| m.name && !m.name.start_with?('Active')}
          includes.each do |i|
            target = self.objects[i.name]
            target.add_included_by(wm) unless target.blank?
          end

          # 該当 object class が呼び出されている object を記録

          wm.methods.each do |name, consts|
            consts.each do |c|
              target = self.objects[c]
              target.add_caller(wm) unless target.blank? || target.caller.include?(wm)
            end
          end

          Prairie::Logger.progress
        end
        Prairie::Logger.finish_progressbar
      end

      def search(target_cname)
        target = self.objects[target_cname]
        if target.blank?
          p "No such module: #{target_cname}"
          return []
        end

        search_const_recursive(target)
      end

      def search_const_recursive(target, result = Prairie::Result.new)
        all_results = []

        # 辿れる繊維が一つもなくなったら終了
        if target.included_by.count == 0 && target.caller.count == 0
          all_results << result
          return all_results
        end

        # include されている object
        target.included_by.each do |next_target|
          next_result = result.deep_dup
          success = next_result.add_stacktrace(path: next_target.file, cname: next_target.name, mname: 'include')
          unless success # loop しそうな場合は終了 TODO 重複
            all_results << next_result
            next
          end

          # 再帰的に操作
          all_results.concat search_const_recursive(next_target, next_result)
        end

        # 呼び出されている object
        target.caller.each do |next_target|
          # 呼び出している method
          next_target_methods = next_target.methods.select {|_, v| v.include?(target.name) }
          next_target_methods.each do |mname, _|
            next_result = result.deep_dup
            success = next_result.add_stacktrace(path: next_target.file, cname: next_target.name, mname: mname) 
            unless success # loop しそうな場合は終了
              all_results << next_result
              next
            end
            next unless success # loop 予防
            all_results.concat search_const_recursive(next_target, next_result)
          end
        end

        # TODO model の relation

        return all_results
      end
    end
  end
end
