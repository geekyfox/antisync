require 'rdoc/task'
require 'rake/testtask'
require 'bundler/gem_tasks'

task default: %w(test)

Rake::TestTask.new(:test) do |t|
  t.test_files = ['test/test_suite.rb']
  t.warning = false
end

RDoc::Task.new(:doc) do |doc|
  doc.main = 'README.rdoc'
  doc.title = 'Antisync Documentation'
  doc.rdoc_dir = 'doc'
  doc.rdoc_files = FileList.new %w(lib/**/*.rb *.rdoc)
end
