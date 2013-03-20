require 'rails/generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator # :nodoc:
      remove_hook_for :resource_controller
      remove_class_option :actions

      class_option :stylesheets, type: :boolean, desc: "Generate Stylesheets"
      class_option :stylesheet_engine, desc: "Engine for Stylesheets"
      class_option :assets, type: :boolean, default: true

      def handle_skip
        @options = @options.merge(stylesheet_engine: false) unless options[:stylesheets]
      end

      hook_for :scaffold_controller, required: true

      hook_for :assets do |assets|
        invoke assets, [controller_name]
      end

      hook_for :stylesheet_engine do |stylesheet_engine|
        if behavior == :invoke
          invoke stylesheet_engine, [controller_name]
        end
      end
    end
  end
end
