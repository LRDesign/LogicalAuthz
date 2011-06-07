Gem::Specification.new do |spec|
  spec.name		= "logical_authz"
  spec.version		= "0.2.0"
  author_list = { 
    #"Evan Dorn"     => "evan@lrdesign.com",  #?
    "Judson Lester" => "judson@lrdesign.com"
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}

  spec.summary		= "Full fledged authorization, starting from one line"
  spec.description	= <<-EOD
  LogicalAuthorization allows authorization in a finely grained framework, including
  ACLs and database based permissions, designed to slide into your project seamlessly.

  You should be able to add logical_authz to your Gemfile and add needs_authorization to
  your base controller class and be done.
  EOD

  spec.rubyforge_project= spec.name.downcase
  spec.homepage             = "http://lrdesign.com/tools"
  if spec.respond_to? :required_rubygems_version=
    spec.required_rubygems_version = Gem::Requirement.new(">= 0") 
  end

  spec.files		= %w[
    LICENSE
    README
    app/views/permissions/index.html.haml
    app/views/permissions/create.rjs
    app/views/permissions/new.html.haml
    app/views/permissions/_controls.html.haml
    app/views/permissions/_form.html.haml
    app/views/permissions/edit.html.haml
    app/views/groups/index.html.haml
    app/views/groups/create.rjs
    app/views/groups/new.html.haml
    app/views/groups/_controls.html.haml
    app/views/groups/_form.html.haml
    app/views/groups/edit.html.haml
    app/views/groups/show.html.haml
    app/controllers/groups_controller.rb
    app/controllers/permissions_controller.rb
    app/controllers/groups_users_controller.rb
    app/helpers/logical_authz_helper.rb
    lib/tasks/rspec.rake
    lib/logical_authz.rb
    lib/logical_authz/configuration.rb
    lib/logical_authz/spec_helper.rb
    lib/logical_authz/generator.rb
    lib/logical_authz/authn_facade/authlogic.rb
    lib/logical_authz/generators/specs/generator.rb
    lib/logical_authz/generators/specs/templates/spec/factories/az_groups.rb
    lib/logical_authz/generators/specs/templates/spec/factories/az_accounts.rb
    lib/logical_authz/generators/specs/templates/spec/factories/permissions.rb
    lib/logical_authz/generators/specs/templates/spec/support/logical_authz.rb
    lib/logical_authz/generators/specs/templates/spec/support/mock_auth.rb
    lib/logical_authz/generators/specs/templates/spec/controllers/permissions_controller_spec.rb
    lib/logical_authz/generators/specs/templates/spec/controllers/groups_controller_spec.rb
    lib/logical_authz/generators/specs/templates/spec/controllers/groups_users_controller_spec.rb
    lib/logical_authz/generators/specs/templates/spec/helpers/logical_authz_helper_spec.rb
    lib/logical_authz/generators/controllers/generator.rb
    lib/logical_authz/generators/controllers/templates/app/controllers/authz_controller.rb
    lib/logical_authz/generators/models/generator.rb
    lib/logical_authz/generators/models/templates/db/seeds_logical_authz.rb
    lib/logical_authz/generators/models/templates/app/models/group.rb
    lib/logical_authz/generators/models/templates/app/models/permission.rb
    lib/logical_authz/generators/models/templates/config/initializers/logical_authz.rb
    lib/logical_authz/generators/models/templates/migrations/create_users_groups.rb
    lib/logical_authz/generators/models/templates/migrations/create_groups.rb
    lib/logical_authz/generators/models/templates/migrations/create_permissions.rb
    lib/logical_authz/generators/routes/generator.rb
    lib/logical_authz/engine.rb
    lib/logical_authz/common.rb
    lib/logical_authz/access_control.rb
    lib/logical_authz/application.rb
    tasks/setup_logical_authz.rake
    generators/logical_authz_specs/logical_authz_specs_generator.rb
    generators/logical_authz/logical_authz_generator.rb
    generators/logical_authz/templates/app/views/layouts/_explain_authz.html.haml.erb
    generators/logical_authz/templates/app/controllers/authz_controller.rb.erb
    generators/logical_authz/templates/README
    generators/logical_authz_models/logical_authz_models_generator.rb
    generators/logical_authz_routes/logical_authz_routes_generator.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.homepage = "http://lrdesign.com/tools"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  dev_deps = [
    ["rake-gemcutter", ">= 0.1.0"],
    ["hanna", "~> 0.1.0"],
    ["mailfactory", "~> 1.4.0"],
    ["rspec", [">= 2.0"]],
    ["bundler", ["~> 1.0.0"]],
    ["rcov", [">= 0"]]
  ]
  if spec.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    spec.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      dev_deps.each do |gem, versions|
        spec.add_development_dependency(gem, versions)
      end
    else
      dev_deps.each do |gem, versions|
        spec.add_dependency(gem, versions)
      end
    end
  else
    dev_deps.each do |gem, versions|
      spec.add_dependency(gem, versions)
    end

  end


  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} RDoc"]

  spec.post_install_message = "Another tidy package brought to you by Logical Reality Design"
end

