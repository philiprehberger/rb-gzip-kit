# frozen_string_literal: true

require_relative 'lib/philiprehberger/gzip_kit/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-gzip_kit'
  spec.version       = Philiprehberger::GzipKit::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']
  spec.summary       = 'Gzip compression and decompression with streaming support'
  spec.description   = 'Simple API for gzip compression and decompression with support for strings, files, ' \
                       'and IO streams. Configurable compression level. Built on Ruby stdlib zlib.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-gzip-kit'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
