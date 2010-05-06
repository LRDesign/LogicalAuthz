module LogicalAuthz
  module CommandExtensions
    module Common
      def route_code(name, path, options)
        options = options.dup
        action = options.delete(:action)
        action ||= options.delete("action")
        controller = options.delete(:controller)
        controller ||= options.delete(:controller)
        options_string = []
        options_string << ":action => #{action.inspect}" unless action.nil?
        options_string << ":controller => #{controller.inspect}" unless controller.nil? 
        unless options.empty?
          match = /\A\{\s*(.*?)\s*\}\Z/.match options.inspect
          remaining_options = match[1]
          remaining_options.gsub!(/([{}]|=>)/){|m| " #{m} "}
          options_string << remaining_options
        end
        options_string = options_string.join(", ")

        "map.#{name} '#{path.to_s}', #{options_string}"
      end
    end

    module Create
      include Common
      def named_route(name, path, options)
        sentinel = 'ActionController::Routing::Routes.draw do |map|'
        insert = route_code(name, path, options)
        logger.add_named_route insert
        if File::open('config/routes.rb').grep(/#{Regexp.escape(insert)}/)
          puts "exists: #{insert}"
        else
          gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/m do |m|
            "#{m}\n  #{insert}"
          end
        end
      end
    end

    module Destroy
      include Common
      def named_route(name, path, options)
        code = route_code(name, path, options)
        logger.remove_route code
        gsub_file 'config/routes.rb', /^\s*#{code}/mi, ''
      end
    end

    module List
      include Common
      def named_route(name, path, options)
        logger.add_named_route route_code(name, path, options)
      end
    end
  end

  Rails::Generator::Commands::List.send :include, CommandExtensions::List
  Rails::Generator::Commands::Create.send :include, CommandExtensions::Create
  Rails::Generator::Commands::Destroy.send :include, CommandExtensions::Destroy

  class Generator < Rails::Generator::Base
    def add_options!(opti)
      opti.on("-u", "--user UserClass"){|val| options[:user_class] = val}
      opti.on("-p", "--permission PermissionClass"){|val| options[:permission_class] = val}
      opti.on("-g", "--group GroupClass"){|val| options[:group_class] = val}
      opti.on("-A", "--admin AdminGroupName"){|val| options[:admin_group] = val}
    end

    def template_data
      @template_data ||= {
        :user_class => options[:user_class],
        :permission_class => options[:permission_class],
        :group_class => options[:group_class],
        :user_table => options[:user_class].tableize,
        :permission_table => options[:permission_class].tableize,
        :group_table => options[:group_class].tableize,
        :user_field => options[:user_class].underscore,
        :permission_field => options[:permission_class].underscore,
        :group_field => options[:group_class].underscore,
        :admin_group => options[:admin_group]
      }
    end
  end
end
