require 'rake'
require 'rspec/core/rake_task'

namespace :logical_authz do
  desc 'Run the specs'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = File::expand_path("../../../spec/**/*_spec.rb", __FILE__)
  end
end

task :spec => 'logical_authz:spec'
