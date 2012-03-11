require "bundler/gem_tasks"
Bundler.require(:defaults, :development)

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:rspec) do |spec|
  spec.rspec_opts = ["--color", "--r spec_helper"]
end

task :default => :rspec

desc "Runs: watchr .watchr"
task :watchr do
  system "watchr .watchr"
end

require 'rdoc/task'
Rake::RDocTask.new do |rd|
  rd.main = "README.md"
  rd.rdoc_files.include("README.md", "lib/**/*.rb")
end
