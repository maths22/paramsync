require_relative 'lib/paramsync/version.rb'

Gem::Specification.new do |s|
  s.name = 'paramsync'
  s.version = Paramsync::VERSION
  s.authors = ['David Adams', 'Jacob Burroughs']
  s.email = 'maths22@gmail.com'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.license = 'CC0'
  s.homepage = 'https://github.com/maths22/paramsync'
  s.required_ruby_version = '>=2.4.0'

  s.summary = 'Simple filesystem-to-aws parameter store synchronization'
  s.description =
    'Syncs content from the filesystem to the aws parameter store.  Derived from constancy for consul'

  s.require_paths = ['lib']
  s.files = Dir["lib/**/*.rb"] + [
    'bin/paramsync',
    'README.md',
    'LICENSE',
    'paramsync.gemspec'
  ]
  s.bindir = 'bin'
  s.executables = ['paramsync']

  s.add_dependency 'imperium', '~>0.3'
  s.add_dependency 'diffy', '~>3.2'
  s.add_dependency 'vault', '~>0.12'

  s.add_development_dependency 'rspec', '~> 3.0'
end
