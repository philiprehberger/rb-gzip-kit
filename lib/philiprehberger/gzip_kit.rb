# frozen_string_literal: true

require 'zlib'
require 'stringio'
require_relative 'gzip_kit/version'

module Philiprehberger
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
    # @return [String] decompressed string
    # @raise [Zlib::GzipFile::Error] if the data is not valid gzip
    def self.decompress(data)
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

      result.force_encoding(Encoding::UTF_8)
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
    # @yield [bytes_processed, total_bytes] progress callback
    # @yieldparam bytes_processed [Integer] bytes processed so far
    # @yieldparam total_bytes [Integer] total file size
    # @return [void]
    def self.compress_file(src, dest, level: Zlib::DEFAULT_COMPRESSION, &block)
      File.open(src, 'rb') do |io_in|
        File.open(dest, 'wb') do |io_out|
          if block
            total_bytes = File.size(src)
            bytes_processed = 0
            gz = Zlib::GzipWriter.new(io_out, level)
            while (chunk = io_in.read(CHUNK_SIZE))
              gz.write(chunk)
              bytes_processed += chunk.bytesize
              block.call(bytes_processed, total_bytes)
            end
            gz.finish
          else
            compress_stream(io_in, io_out, level: level)
          end
        end
      end
    end

    # Decompress a gzip file to a regular file.
    #
    # @param src [String] path to the gzip source file
    # @param dest [String] path to the destination file
    # @yield [bytes_processed, total_bytes] progress callback
    # @yieldparam bytes_processed [Integer] bytes decompressed so far
    # @yieldparam total_bytes [nil] always nil (total unknown until decompression completes)
    # @return [void]
    def self.decompress_file(src, dest, &block)
      File.open(src, 'rb') do |io_in|
        File.open(dest, 'wb') do |io_out|
          if block
            gz = Zlib::GzipReader.new(io_in)
            bytes_processed = 0
            while (chunk = gz.read(CHUNK_SIZE))
              io_out.write(chunk)
              bytes_processed += chunk.bytesize
              block.call(bytes_processed, nil)
            end
            gz.close
          else
            decompress_stream(io_in, io_out)
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

    # Streaming compression from one IO to another, reading in 64KB chunks.
    #
    # @param io_in [IO] readable input stream
    # @param io_out [IO] writable output stream
    # @param level [Integer] compression level (Zlib::DEFAULT_COMPRESSION by default)
    # @return [void]
    def self.compress_stream(io_in, io_out, level: Zlib::DEFAULT_COMPRESSION)
      gz = Zlib::GzipWriter.new(io_out, level)
      while (chunk = io_in.read(CHUNK_SIZE))
        gz.write(chunk)
      end
      gz.finish
    end

    # Streaming decompression from one IO to another, reading in 64KB chunks.
    #
    # @param io_in [IO] readable input stream containing gzip data
    # @param io_out [IO] writable output stream
    # @return [void]
    def self.decompress_stream(io_in, io_out)
      gz = Zlib::GzipReader.new(io_in)
      while (chunk = gz.read(CHUNK_SIZE))
        io_out.write(chunk)
      end
    ensure
      gz&.close
    end
  end
end
