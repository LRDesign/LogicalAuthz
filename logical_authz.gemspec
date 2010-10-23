require 'rubygems'

SPEC = Gem::Specification.new do |spec|
  spec.name		= "logical_authz"
  spec.version		= "0.1.0"
  spec.author		= "Judson Lester"
  spec.email		= "judson@lrdesign.com"
  spec.summary		= "Full fledged authorization, starting from one line"
  spec.description	= <<-EOD
  LogicalAuthorization allows authorization in a finely grained framework, including
  ACLs and database based permissions, designed to slide into your project seamlessly.

  You should be able to add logical_authz to your Gemfile and add needs_authorization to
  your base controller class and be done.
  EOD

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://#{spec.rubyforge_project}.rubyforge.org/"

  spec.files		+= Dir.glob("lib/**/*")
  spec.files		+= Dir.glob("doc/**/*")
  spec.files		+= Dir.glob("spec/**/*")

  spec.test_file        = "spec_help/gem_test_suite.rb"
  
  spec.require_path	= "lib" 

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} RDoc"]

  spec.post_install_message = "Another tidy package brought to you by Logical Reality Design"
end

RUBYFORGE = {
  :group_id => SPEC.rubyforge_project,
  :package_id => SPEC.name.downcase,
  :release_name => SPEC.full_name,
  :home_page => SPEC.homepage,
  :project_page => "http://rubyforge.org/project/#{SPEC.rubyforge_project}/"
}

SPEC
