# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "<%= name %>/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "<%= name %>"
  s.version     = <%= camelized %>::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = ""
  s.summary     = "TODO: Summary of <%= camelized %>."
  s.description = "TODO: Description of <%= camelized %>."

  s.rubyforge_project = "<%= name %>"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
<% unless options.skip_test_unit? -%>
  s.test_files = Dir["test/**/*"]
<% end -%>
  s.require_paths = ["lib"]

  # If your gem is dependent on a specific version (or higher) of Rails:
  <%= '# ' if options.dev? || options.edge? -%>s.add_dependency "rails", ">= <%= Rails::VERSION::STRING %>"

<% unless options[:skip_javascript] -%>
  # If your gem contains any <%= "#{options[:javascript]}-specific" %> javascript:
  # s.add_dependency "<%= "#{options[:javascript]}-rails" %>"

<% end -%>
  # Declare development-specific dependencies:
  s.add_development_dependency "<%= gem_for_database %>"
  # s.add_development_dependency "rspec"
end
