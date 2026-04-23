# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-04-23

### Added
- Optional `chunk_size:` keyword on `compress_stream`, `decompress_stream`, `compress_file`, `decompress_file` (defaults to 64 KB).
- Optional `stats:` keyword on `decompress` — returns `{ data:, ratio: }` when true.
- Module-level YARD overview and `@example` blocks on primary methods.

## [0.3.0] - 2026-04-16

### Added
- `GzipKit.equivalent?(blob_a, blob_b)` — returns true iff both gzip-compressed inputs decompress to equal byte strings; raises `GzipKit::Error` if either input is not valid gzip

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

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
