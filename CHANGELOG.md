# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-28

### Added

- `GzipKit.compress(string, stats: true)` returns a hash with compression statistics (data, ratio, original_size, compressed_size)
- `GzipKit.compressed?(data)` checks for gzip magic bytes to detect compressed data
- Progress callbacks for `compress_file` and `decompress_file` via block argument
- `GzipKit.concat(data_a, data_b)` concatenates two gzip-compressed strings per gzip spec
- `GzipKit.inspect_header(data)` reads gzip header metadata without decompressing

## [0.1.1] - 2026-03-26

### Added

- Add GitHub funding configuration

## [0.1.0] - 2026-03-26

### Added
- Initial release
- `GzipKit.compress` and `GzipKit.decompress` for string compression
- `GzipKit.compress_file` and `GzipKit.decompress_file` for file operations
- `GzipKit.compress_stream` and `GzipKit.decompress_stream` for streaming IO
- Configurable compression level via `level:` keyword argument
- 64KB chunk-based streaming for memory-efficient processing
