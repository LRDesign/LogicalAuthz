require 'rake'
require 'spec/rake/spectask'


namespace :logical_authz do
  desc 'Run the specs'
  Spec::Rake::SpecTask.new(:spec) do |t|
    t.spec_opts = ['--colour --format progress --loadby mtime --reverse']
    t.spec_files = FileList['spec/**/*_spec.rb']
  end
end

task :spec => 'logical_authz:spec'
