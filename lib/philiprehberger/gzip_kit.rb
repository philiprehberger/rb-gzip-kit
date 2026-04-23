# frozen_string_literal: true

require 'zlib'
require 'stringio'
require_relative 'gzip_kit/version'

module Philiprehberger
  # GzipKit provides gzip compression and decompression with streaming support.
  #
  # The module exposes both string-oriented and IO-oriented entry points:
  #
  # - {GzipKit.compress} / {GzipKit.decompress} for in-memory string data
  # - {GzipKit.compress_stream} / {GzipKit.decompress_stream} for IO-to-IO streaming
  # - {GzipKit.compress_file} / {GzipKit.decompress_file} for file-to-file transforms
  # - {GzipKit.compressed?} / {GzipKit.inspect_header} for gzip detection and header inspection
  # - {GzipKit.concat} / {GzipKit.equivalent?} for combining and comparing gzip blobs
  #
  # Streaming and file methods read in 64 KB chunks by default. The chunk size can be
  # tuned via the +chunk_size:+ keyword when dealing with very small or very large payloads.
  #
  # @example Compress and decompress a string
  #   compressed = Philiprehberger::GzipKit.compress('hello')
  #   Philiprehberger::GzipKit.decompress(compressed) # => "hello"
  module GzipKit
    class Error < StandardError; end

    CHUNK_SIZE = 64 * 1024
    GZIP_MAGIC = [0x1f, 0x8b].freeze

    # Compress a string to gzip bytes.
    #
    # @param string [String] the data to compress
    # @param level [Integer] compression level (Zlib::DEFAULT_COMPRESSION by default)
    # @param stats [Boolean] when true, return a hash with compression statistics
    # @return [String, Hash] gzip-compressed bytes, or a stats hash when stats: true
    #
    # @example Compress a string
    #   Philiprehberger::GzipKit.compress('hello, world!')
    #   # => "\x1F\x8B\b\x00..." (binary gzip bytes)
    #
    # @example Compress with stats
    #   Philiprehberger::GzipKit.compress('a' * 10_000, stats: true)
    #   # => { data: "...", ratio: 0.99, original_size: 10000, compressed_size: 41 }
    def self.compress(string, level: Zlib::DEFAULT_COMPRESSION, stats: false)
      io_out = StringIO.new
      io_out.binmode
      gz = Zlib::GzipWriter.new(io_out, level)
      gz.write(string)
      gz.close
      compressed = io_out.string

      if stats
        original_size = string.bytesize
        compressed_size = compressed.bytesize
        ratio = original_size.zero? ? 0.0 : 1.0 - (compressed_size.to_f / original_size)
        {
          data: compressed,
          ratio: ratio,
          original_size: original_size,
          compressed_size: compressed_size
        }
      else
        compressed
      end
    end

    # Decompress gzip bytes to a string.
    #
    # @param data [String] gzip-compressed bytes
    # @param stats [Boolean] when true, return a hash with decompression statistics
    # @return [String, Hash] decompressed string, or a stats hash when stats: true
    # @raise [Zlib::GzipFile::Error] if the data is not valid gzip
    #
    # @example Decompress gzip bytes
    #   compressed = Philiprehberger::GzipKit.compress('hello')
    #   Philiprehberger::GzipKit.decompress(compressed) # => "hello"
    #
    # @example Decompress with stats
    #   compressed = Philiprehberger::GzipKit.compress('a' * 10_000)
    #   Philiprehberger::GzipKit.decompress(compressed, stats: true)
    #   # => { data: "aaaa...", ratio: 0.0041 }
    def self.decompress(data, stats: false)
      io_in = StringIO.new(data)
      io_in.binmode
      result = String.new(encoding: Encoding::BINARY)

      # Handle concatenated gzip streams per gzip spec
      until io_in.eof?
        gz = Zlib::GzipReader.new(io_in)
        result << gz.read
        # GzipReader leaves io_in positioned after the stream
        unused = gz.unused
        gz.finish
        if unused
          io_in.pos -= unused.bytesize
        end
      end

      decompressed = result.force_encoding(Encoding::UTF_8)

      if stats
        decompressed_size = decompressed.bytesize
        compressed_size = data.bytesize
        ratio = decompressed_size.zero? ? 0.0 : compressed_size.to_f / decompressed_size
        { data: decompressed, ratio: ratio }
      else
        decompressed
      end
    end

    # Check if data is gzip-compressed by inspecting magic bytes.
    #
    # @param data [String] data to check
    # @return [Boolean] true if data starts with gzip magic bytes
    def self.compressed?(data)
      return false if data.nil? || data.bytesize < 2

      bytes = data.bytes
      bytes[0] == GZIP_MAGIC[0] && bytes[1] == GZIP_MAGIC[1]
    end

    # Compress a file to a gzip file.
    #
    # @param src [String] path to the source file
    # @param dest [String] path to the destination gzip file
    # @param level [Integer] compression level (Zlib::DEFAULT_COMPRESSION by default)
    # @param chunk_size [Integer] bytes per read chunk (defaults to 64 KB)
    # @yield [bytes_processed, total_bytes] progress callback
    # @yieldparam bytes_processed [Integer] bytes processed so far
    # @yieldparam total_bytes [Integer] total file size
    # @return [void]
    # @raise [ArgumentError] if chunk_size is not a positive Integer
    def self.compress_file(src, dest, level: Zlib::DEFAULT_COMPRESSION, chunk_size: CHUNK_SIZE, &block)
      validate_chunk_size!(chunk_size)

      File.open(src, 'rb') do |io_in|
        File.open(dest, 'wb') do |io_out|
          if block
            total_bytes = File.size(src)
            bytes_processed = 0
            gz = Zlib::GzipWriter.new(io_out, level)
            while (chunk = io_in.read(chunk_size))
              gz.write(chunk)
              bytes_processed += chunk.bytesize
              block.call(bytes_processed, total_bytes)
            end
            gz.finish
          else
            compress_stream(io_in, io_out, level: level, chunk_size: chunk_size)
          end
        end
      end
    end

    # Decompress a gzip file to a regular file.
    #
    # @param src [String] path to the gzip source file
    # @param dest [String] path to the destination file
    # @param chunk_size [Integer] bytes per read chunk (defaults to 64 KB)
    # @yield [bytes_processed, total_bytes] progress callback
    # @yieldparam bytes_processed [Integer] bytes decompressed so far
    # @yieldparam total_bytes [nil] always nil (total unknown until decompression completes)
    # @return [void]
    # @raise [ArgumentError] if chunk_size is not a positive Integer
    def self.decompress_file(src, dest, chunk_size: CHUNK_SIZE, &block)
      validate_chunk_size!(chunk_size)

      File.open(src, 'rb') do |io_in|
        File.open(dest, 'wb') do |io_out|
          if block
            gz = Zlib::GzipReader.new(io_in)
            bytes_processed = 0
            while (chunk = gz.read(chunk_size))
              io_out.write(chunk)
              bytes_processed += chunk.bytesize
              block.call(bytes_processed, nil)
            end
            gz.close
          else
            decompress_stream(io_in, io_out, chunk_size: chunk_size)
          end
        end
      end
    end

    # Concatenate two gzip-compressed strings.
    #
    # Per the gzip specification, concatenated gzip streams are valid.
    #
    # @param data_a [String] first gzip-compressed string
    # @param data_b [String] second gzip-compressed string
    # @return [String] concatenated gzip data
    # @raise [Error] if either input is not valid gzip
    def self.concat(data_a, data_b)
      raise Error, 'first argument is not valid gzip data' unless compressed?(data_a)
      raise Error, 'second argument is not valid gzip data' unless compressed?(data_b)

      result = String.new(data_a, encoding: Encoding::BINARY)
      result << data_b.b
      result
    end

    # Check whether two gzip-compressed blobs decompress to equal byte strings.
    #
    # Useful for comparing gzip outputs produced at different compression levels
    # or with different metadata — only the decompressed payloads are compared.
    #
    # @param blob_a [String] first gzip-compressed string
    # @param blob_b [String] second gzip-compressed string
    # @return [Boolean] true iff both blobs decompress to equal byte strings
    # @raise [Error] if either input is not valid gzip
    def self.equivalent?(blob_a, blob_b)
      raise Error, 'first argument is not valid gzip data' unless compressed?(blob_a)
      raise Error, 'second argument is not valid gzip data' unless compressed?(blob_b)

      decompress(blob_a).b == decompress(blob_b).b
    rescue Zlib::GzipFile::Error => e
      raise Error, "failed to decompress gzip data: #{e.message}"
    end

    # Inspect the gzip header without decompressing.
    #
    # @param data [String] gzip-compressed data
    # @return [Hash, nil] header info or nil if not valid gzip
    def self.inspect_header(data)
      return nil unless compressed?(data)

      io = StringIO.new(data)
      io.binmode
      gz = Zlib::GzipReader.new(io)

      {
        method: :deflate,
        mtime: gz.mtime,
        os: gz.os_code,
        original_name: gz.orig_name && gz.orig_name.empty? ? nil : gz.orig_name,
        comment: gz.comment && gz.comment.empty? ? nil : gz.comment
      }
    rescue Zlib::GzipFile::Error
      nil
    ensure
      gz&.close
    end

    # Streaming compression from one IO to another.
    #
    # @param io_in [IO] readable input stream
    # @param io_out [IO] writable output stream
    # @param level [Integer] compression level (Zlib::DEFAULT_COMPRESSION by default)
    # @param chunk_size [Integer] bytes per read chunk (defaults to 64 KB)
    # @return [void]
    # @raise [ArgumentError] if chunk_size is not a positive Integer
    #
    # @example Compress from one IO to another
    #   File.open('input.txt', 'rb') do |io_in|
    #     File.open('output.gz', 'wb') do |io_out|
    #       Philiprehberger::GzipKit.compress_stream(io_in, io_out)
    #     end
    #   end
    #
    # @example Tune the chunk size for small payloads
    #   Philiprehberger::GzipKit.compress_stream(io_in, io_out, chunk_size: 4 * 1024)
    def self.compress_stream(io_in, io_out, level: Zlib::DEFAULT_COMPRESSION, chunk_size: CHUNK_SIZE)
      validate_chunk_size!(chunk_size)

      gz = Zlib::GzipWriter.new(io_out, level)
      while (chunk = io_in.read(chunk_size))
        gz.write(chunk)
      end
      gz.finish
    end

    # Streaming decompression from one IO to another.
    #
    # @param io_in [IO] readable input stream containing gzip data
    # @param io_out [IO] writable output stream
    # @param chunk_size [Integer] bytes per read chunk (defaults to 64 KB)
    # @return [void]
    # @raise [ArgumentError] if chunk_size is not a positive Integer
    #
    # @example Decompress from one IO to another
    #   File.open('output.gz', 'rb') do |io_in|
    #     File.open('restored.txt', 'wb') do |io_out|
    #       Philiprehberger::GzipKit.decompress_stream(io_in, io_out)
    #     end
    #   end
    def self.decompress_stream(io_in, io_out, chunk_size: CHUNK_SIZE)
      validate_chunk_size!(chunk_size)

      gz = Zlib::GzipReader.new(io_in)
      while (chunk = gz.read(chunk_size))
        io_out.write(chunk)
      end
    ensure
      gz&.close
    end

    # @api private
    def self.validate_chunk_size!(chunk_size)
      return if chunk_size.is_a?(Integer) && chunk_size.positive?

      raise ArgumentError, "chunk_size must be a positive Integer, got: #{chunk_size.inspect}"
    end
    private_class_method :validate_chunk_size!
  end
end
