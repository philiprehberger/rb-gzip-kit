# frozen_string_literal: true

require "zlib"
require "stringio"
require_relative "gzip_kit/version"

module Philiprehberger
  module GzipKit
    class Error < StandardError; end

    CHUNK_SIZE = 64 * 1024

    # Compress a string to gzip bytes.
    #
    # @param string [String] the data to compress
    # @param level [Integer] compression level (Zlib::DEFAULT_COMPRESSION by default)
    # @return [String] gzip-compressed bytes
    def self.compress(string, level: Zlib::DEFAULT_COMPRESSION)
      io_out = StringIO.new
      io_out.binmode
      gz = Zlib::GzipWriter.new(io_out, level)
      gz.write(string)
      gz.close
      io_out.string
    end

    # Decompress gzip bytes to a string.
    #
    # @param data [String] gzip-compressed bytes
    # @return [String] decompressed string
    # @raise [Zlib::GzipFile::Error] if the data is not valid gzip
    def self.decompress(data)
      io_in = StringIO.new(data)
      io_in.binmode
      gz = Zlib::GzipReader.new(io_in)
      gz.read
    ensure
      gz&.close
    end

    # Compress a file to a gzip file.
    #
    # @param src [String] path to the source file
    # @param dest [String] path to the destination gzip file
    # @param level [Integer] compression level (Zlib::DEFAULT_COMPRESSION by default)
    # @return [void]
    def self.compress_file(src, dest, level: Zlib::DEFAULT_COMPRESSION)
      File.open(src, "rb") do |io_in|
        File.open(dest, "wb") do |io_out|
          compress_stream(io_in, io_out, level: level)
        end
      end
    end

    # Decompress a gzip file to a regular file.
    #
    # @param src [String] path to the gzip source file
    # @param dest [String] path to the destination file
    # @return [void]
    def self.decompress_file(src, dest)
      File.open(src, "rb") do |io_in|
        File.open(dest, "wb") do |io_out|
          decompress_stream(io_in, io_out)
        end
      end
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
