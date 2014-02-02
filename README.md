# philiprehberger-gzip_kit

[![Tests](https://github.com/philiprehberger/rb-gzip-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-gzip-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-gzip_kit.svg)](https://rubygems.org/gems/philiprehberger-gzip_kit)
[![License](https://img.shields.io/github/license/philiprehberger/rb-gzip-kit)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Gzip compression and decompression with streaming support

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-gzip_kit"
```

Or install directly:

```bash
gem install philiprehberger-gzip_kit
```

## Usage

```ruby
require "philiprehberger/gzip_kit"

compressed = Philiprehberger::GzipKit.compress("Hello, world!")
original = Philiprehberger::GzipKit.decompress(compressed)
```

### Compression Levels

```ruby
require "philiprehberger/gzip_kit"

# Fast compression
fast = Philiprehberger::GzipKit.compress(data, level: Zlib::BEST_SPEED)

# Maximum compression
small = Philiprehberger::GzipKit.compress(data, level: Zlib::BEST_COMPRESSION)

# No compression (store only)
raw = Philiprehberger::GzipKit.compress(data, level: Zlib::NO_COMPRESSION)
```

### File Operations

```ruby
require "philiprehberger/gzip_kit"

# Compress a file
Philiprehberger::GzipKit.compress_file("data.txt", "data.txt.gz")

# Decompress a file
Philiprehberger::GzipKit.decompress_file("data.txt.gz", "data.txt")

# Compress with custom level
Philiprehberger::GzipKit.compress_file("data.txt", "data.txt.gz", level: Zlib::BEST_COMPRESSION)
```

### Streaming

```ruby
require "philiprehberger/gzip_kit"

# Compress from one IO to another
File.open("input.txt", "rb") do |input|
  File.open("output.gz", "wb") do |output|
    Philiprehberger::GzipKit.compress_stream(input, output)
  end
end

# Decompress from one IO to another
File.open("output.gz", "rb") do |input|
  File.open("restored.txt", "wb") do |output|
    Philiprehberger::GzipKit.decompress_stream(input, output)
  end
end
```

## API

| Method | Description |
|--------|-------------|
| `GzipKit.compress(string, level:)` | Compress a string to gzip bytes |
| `GzipKit.decompress(data)` | Decompress gzip bytes to a string |
| `GzipKit.compress_file(src, dest, level:)` | Compress a file to a gzip file |
| `GzipKit.decompress_file(src, dest)` | Decompress a gzip file to a regular file |
| `GzipKit.compress_stream(io_in, io_out, level:)` | Streaming compression in 64KB chunks |
| `GzipKit.decompress_stream(io_in, io_out)` | Streaming decompression in 64KB chunks |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE)
