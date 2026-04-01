# frozen_string_literal: true

require_relative 'lib/philiprehberger/gzip_kit/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-gzip_kit'
  spec.version = Philiprehberger::GzipKit::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']
  spec.summary = 'Gzip compression and decompression with streaming support'
  spec.description = 'Simple API for gzip compression and decompression with support for strings, files, ' \
                     'and IO streams. Configurable compression level. Built on Ruby stdlib zlib.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-gzip_kit'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-gzip-kit'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-gzip-kit/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-gzip-kit/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
