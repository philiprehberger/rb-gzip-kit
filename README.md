# philiprehberger-gzip_kit

[![Tests](https://github.com/philiprehberger/rb-gzip-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-gzip-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-gzip_kit.svg)](https://rubygems.org/gems/philiprehberger-gzip_kit)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-gzip-kit)](https://github.com/philiprehberger/rb-gzip-kit/commits/main)

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

### Compression Stats

```ruby
require "philiprehberger/gzip_kit"

result = Philiprehberger::GzipKit.compress(data, stats: true)
# => { data: "...", ratio: 0.85, original_size: 10000, compressed_size: 1500 }
```

### Gzip Detection

```ruby
require "philiprehberger/gzip_kit"

Philiprehberger::GzipKit.compressed?(gzip_data)  # => true
Philiprehberger::GzipKit.compressed?("plain text") # => false
```

### File Operations

```ruby
require "philiprehberger/gzip_kit"

# Compress a file
Philiprehberger::GzipKit.compress_file("data.txt", "data.txt.gz")

# Decompress a file
Philiprehberger::GzipKit.decompress_file("data.txt.gz", "data.txt")

# Compress with progress callback
Philiprehberger::GzipKit.compress_file("data.txt", "data.txt.gz") do |bytes_processed, total_bytes|
  puts "#{bytes_processed}/#{total_bytes} bytes"
end

# Decompress with progress callback (total_bytes is nil)
Philiprehberger::GzipKit.decompress_file("data.txt.gz", "data.txt") do |bytes_processed, total_bytes|
  puts "#{bytes_processed} bytes decompressed"
end
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

### Stream Concatenation

```ruby
require "philiprehberger/gzip_kit"

part_a = Philiprehberger::GzipKit.compress("Hello, ")
part_b = Philiprehberger::GzipKit.compress("world!")
combined = Philiprehberger::GzipKit.concat(part_a, part_b)

Philiprehberger::GzipKit.decompress(combined) # => "Hello, world!"
```

### Header Inspection

```ruby
require "philiprehberger/gzip_kit"

header = Philiprehberger::GzipKit.inspect_header(gzip_data)
# => { method: :deflate, mtime: 2026-03-28 12:00:00 +0000, os: 255, original_name: nil, comment: nil }
```

## API

| Method | Description |
|--------|-------------|
| `GzipKit.compress(string, level:, stats:)` | Compress a string to gzip bytes; returns stats hash when `stats: true` |
| `GzipKit.decompress(data)` | Decompress gzip bytes to a string |
| `GzipKit.compressed?(data)` | Check if data is gzip-compressed via magic bytes |
| `GzipKit.compress_file(src, dest, level:, &block)` | Compress a file to a gzip file with optional progress callback |
| `GzipKit.decompress_file(src, dest, &block)` | Decompress a gzip file with optional progress callback |
| `GzipKit.compress_stream(io_in, io_out, level:)` | Streaming compression in 64KB chunks |
| `GzipKit.decompress_stream(io_in, io_out)` | Streaming decompression in 64KB chunks |
| `GzipKit.concat(data_a, data_b)` | Concatenate two gzip-compressed strings |
| `GzipKit.inspect_header(data)` | Read gzip header metadata without decompressing |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-gzip-kit)

🐛 [Report issues](https://github.com/philiprehberger/rb-gzip-kit/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-gzip-kit/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
