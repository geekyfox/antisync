Gem::Specification.new do |s|
  s.name        = 'antisync'
  s.version     = '0.1.0'
  s.date        = '2017-01-01'
  s.summary     = 'Antisync'
  s.description = 'Command-line client for Antiblog'
  s.authors     = ['Ivan Appel']
  s.email       = 'ivan.appel@gmail.com'
  s.files       = [
    'lib/antisync.rb',
    'lib/antisync/cmdargs.rb',
    'lib/antisync/parser.rb'
  ]
  s.executables << 'antisync'
  s.homepage    = 'http://github.com/geekyfox/antisync'
  s.license     = 'MIT'

  s.add_development_dependency 'simplecov', '~> 0.12'
  s.add_development_dependency 'test-unit', '~> 3.2'
end
