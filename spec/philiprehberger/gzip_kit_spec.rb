# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe Philiprehberger::GzipKit do
  it 'has a version number' do
    expect(Philiprehberger::GzipKit::VERSION).not_to be_nil
  end

  describe '.compress and .decompress' do
    it 'roundtrips a simple string' do
      original = 'Hello, gzip world!'
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it 'produces output smaller than original for compressible data' do
      original = 'a' * 10_000
      compressed = described_class.compress(original)

      expect(compressed.bytesize).to be < original.bytesize
    end

    it 'handles an empty string' do
      compressed = described_class.compress('')
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq('')
    end

    it 'handles binary data' do
      original = (0..255).map(&:chr).join * 10
      original = original.dup.force_encoding(Encoding::BINARY)
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed.bytes).to eq(original.bytes)
    end

    it 'handles large data' do
      original = 'x' * 1_000_000
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it 'handles multi-byte UTF-8 strings' do
      original = "Hello \u00e9\u00e8\u00ea \u3053\u3093\u306b\u3061\u306f"
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed.force_encoding(Encoding::UTF_8)).to eq(original)
    end
  end

  describe '.compress with stats' do
    it 'returns a string when stats is false' do
      result = described_class.compress('Hello', stats: false)

      expect(result).to be_a(String)
    end

    it 'returns a string when stats is not provided' do
      result = described_class.compress('Hello')

      expect(result).to be_a(String)
    end

    it 'returns a hash with stats when stats is true' do
      original = 'a' * 10_000
      result = described_class.compress(original, stats: true)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:data)
      expect(result).to have_key(:ratio)
      expect(result).to have_key(:original_size)
      expect(result).to have_key(:compressed_size)
    end

    it 'includes valid compressed data in the stats hash' do
      original = 'Hello, stats world!'
      result = described_class.compress(original, stats: true)
      decompressed = described_class.decompress(result[:data])

      expect(decompressed).to eq(original)
    end

    it 'reports correct sizes' do
      original = 'a' * 10_000
      result = described_class.compress(original, stats: true)

      expect(result[:original_size]).to eq(10_000)
      expect(result[:compressed_size]).to eq(result[:data].bytesize)
      expect(result[:compressed_size]).to be < result[:original_size]
    end

    it 'calculates compression ratio correctly' do
      original = 'a' * 10_000
      result = described_class.compress(original, stats: true)
      expected_ratio = 1.0 - (result[:compressed_size].to_f / result[:original_size])

      expect(result[:ratio]).to be_within(0.0001).of(expected_ratio)
    end

    it 'returns zero ratio for empty string' do
      result = described_class.compress('', stats: true)

      expect(result[:ratio]).to eq(0.0)
      expect(result[:original_size]).to eq(0)
    end

    it 'works with custom compression level and stats' do
      original = 'b' * 5_000
      result = described_class.compress(original, level: Zlib::BEST_COMPRESSION, stats: true)

      expect(result[:data]).to be_a(String)
      expect(result[:ratio]).to be > 0
    end
  end

  describe 'compression levels' do
    it 'compresses with Zlib::BEST_SPEED' do
      original = 'a' * 10_000
      compressed = described_class.compress(original, level: Zlib::BEST_SPEED)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it 'compresses with Zlib::BEST_COMPRESSION' do
      original = 'a' * 10_000
      compressed = described_class.compress(original, level: Zlib::BEST_COMPRESSION)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it 'compresses with Zlib::NO_COMPRESSION' do
      original = 'Hello, no compression!'
      compressed = described_class.compress(original, level: Zlib::NO_COMPRESSION)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it 'produces smaller output with higher compression' do
      original = 'abcdefghij' * 5_000
      fast = described_class.compress(original, level: Zlib::BEST_SPEED)
      best = described_class.compress(original, level: Zlib::BEST_COMPRESSION)

      expect(best.bytesize).to be <= fast.bytesize
    end
  end

  describe '.compressed?' do
    it 'returns true for gzip-compressed data' do
      compressed = described_class.compress('Hello')

      expect(described_class.compressed?(compressed)).to be true
    end

    it 'returns false for plain text' do
      expect(described_class.compressed?('Hello, world!')).to be false
    end

    it 'returns false for nil' do
      expect(described_class.compressed?(nil)).to be false
    end

    it 'returns false for an empty string' do
      expect(described_class.compressed?('')).to be false
    end

    it 'returns false for a single byte' do
      expect(described_class.compressed?("\x1f")).to be false
    end

    it 'returns true for data starting with gzip magic bytes' do
      data = "\x1f\x8b\x08\x00rest_of_header"

      expect(described_class.compressed?(data)).to be true
    end

    it 'returns false for data with only first magic byte matching' do
      data = "\x1f\x00\x08\x00"

      expect(described_class.compressed?(data)).to be false
    end

    it 'returns true for empty gzip stream' do
      compressed = described_class.compress('')

      expect(described_class.compressed?(compressed)).to be true
    end

    it 'handles binary strings' do
      compressed = described_class.compress('binary test')

      expect(described_class.compressed?(compressed.b)).to be true
    end
  end

  describe '.compress_file and .decompress_file' do
    it 'roundtrips a file' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        original_content = "File compression test content.\n" * 100
        File.write(src, original_content)

        described_class.compress_file(src, compressed)
        expect(File.exist?(compressed)).to be true
        expect(File.size(compressed)).to be > 0
        expect(File.size(compressed)).to be < File.size(src)

        described_class.decompress_file(compressed, output)
        expect(File.read(output)).to eq(original_content)
      end
    end

    it 'roundtrips a binary file' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'binary.dat')
        compressed = File.join(dir, 'binary.dat.gz')
        output = File.join(dir, 'binary_out.dat')

        original_bytes = (0..255).map(&:chr).join * 100
        File.binwrite(src, original_bytes)

        described_class.compress_file(src, compressed)
        described_class.decompress_file(compressed, output)

        expect(File.binread(output)).to eq(original_bytes)
      end
    end

    it 'roundtrips a file with custom compression level' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        original_content = "Custom level test.\n" * 500
        File.write(src, original_content)

        described_class.compress_file(src, compressed, level: Zlib::BEST_COMPRESSION)
        described_class.decompress_file(compressed, output)

        expect(File.read(output)).to eq(original_content)
      end
    end
  end

  describe '.compress_file with progress callback' do
    it 'yields progress during compression' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')

        content = 'x' * 200_000
        File.write(src, content)

        progress_calls = []
        described_class.compress_file(src, compressed) do |bytes_processed, total_bytes|
          progress_calls << [bytes_processed, total_bytes]
        end

        expect(progress_calls).not_to be_empty
        expect(progress_calls.last[0]).to eq(content.bytesize)
        expect(progress_calls.last[1]).to eq(content.bytesize)
      end
    end

    it 'reports correct total_bytes as file size' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')

        content = 'y' * 50_000
        File.write(src, content)

        total_values = []
        described_class.compress_file(src, compressed) do |_bytes_processed, total_bytes|
          total_values << total_bytes
        end

        expect(total_values.uniq).to eq([content.bytesize])
      end
    end

    it 'produces valid gzip output with progress callback' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        content = "Progress test content.\n" * 1_000
        File.write(src, content)

        described_class.compress_file(src, compressed) { |_b, _t| }
        described_class.decompress_file(compressed, output)

        expect(File.read(output)).to eq(content)
      end
    end

    it 'reports monotonically increasing bytes_processed' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')

        File.write(src, 'z' * 200_000)

        processed_values = []
        described_class.compress_file(src, compressed) do |bytes_processed, _total|
          processed_values << bytes_processed
        end

        expect(processed_values).to eq(processed_values.sort)
        expect(processed_values.first).to be > 0
      end
    end
  end

  describe '.decompress_file with progress callback' do
    it 'yields progress during decompression' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        content = 'x' * 200_000
        File.write(src, content)
        described_class.compress_file(src, compressed)

        progress_calls = []
        described_class.decompress_file(compressed, output) do |bytes_processed, total_bytes|
          progress_calls << [bytes_processed, total_bytes]
        end

        expect(progress_calls).not_to be_empty
        expect(progress_calls.last[0]).to eq(content.bytesize)
      end
    end

    it 'reports nil for total_bytes during decompression' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        File.write(src, 'data' * 10_000)
        described_class.compress_file(src, compressed)

        total_values = []
        described_class.decompress_file(compressed, output) do |_bytes_processed, total_bytes|
          total_values << total_bytes
        end

        expect(total_values.uniq).to eq([nil])
      end
    end

    it 'produces correct output with progress callback' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        content = "Decompression progress test.\n" * 1_000
        File.write(src, content)
        described_class.compress_file(src, compressed)

        described_class.decompress_file(compressed, output) { |_b, _t| }

        expect(File.read(output)).to eq(content)
      end
    end
  end

  describe '.concat' do
    it 'concatenates two gzip streams' do
      data_a = described_class.compress('Hello, ')
      data_b = described_class.compress('world!')
      result = described_class.concat(data_a, data_b)

      decompressed = described_class.decompress(result)

      expect(decompressed).to eq('Hello, world!')
    end

    it 'returns valid gzip data' do
      data_a = described_class.compress('first')
      data_b = described_class.compress('second')
      result = described_class.concat(data_a, data_b)

      expect(described_class.compressed?(result)).to be true
    end

    it 'raises an error if first argument is not gzip' do
      data_b = described_class.compress('valid')

      expect { described_class.concat('not gzip', data_b) }.to raise_error(
        Philiprehberger::GzipKit::Error, 'first argument is not valid gzip data'
      )
    end

    it 'raises an error if second argument is not gzip' do
      data_a = described_class.compress('valid')

      expect { described_class.concat(data_a, 'not gzip') }.to raise_error(
        Philiprehberger::GzipKit::Error, 'second argument is not valid gzip data'
      )
    end

    it 'raises an error if both arguments are not gzip' do
      expect { described_class.concat('bad', 'data') }.to raise_error(
        Philiprehberger::GzipKit::Error
      )
    end

    it 'handles concatenation with empty gzip streams' do
      data_a = described_class.compress('')
      data_b = described_class.compress('content')
      result = described_class.concat(data_a, data_b)

      decompressed = described_class.decompress(result)

      expect(decompressed).to eq('content')
    end

    it 'handles concatenation of two empty gzip streams' do
      data_a = described_class.compress('')
      data_b = described_class.compress('')
      result = described_class.concat(data_a, data_b)

      decompressed = described_class.decompress(result)

      expect(decompressed).to eq('')
    end

    it 'preserves binary encoding' do
      data_a = described_class.compress('abc')
      data_b = described_class.compress('def')
      result = described_class.concat(data_a, data_b)

      expect(result.encoding).to eq(Encoding::BINARY)
    end
  end

  describe '.equivalent?' do
    it 'returns true for identical compressed bytes' do
      blob = described_class.compress('hello, world!')

      expect(described_class.equivalent?(blob, blob)).to be true
    end

    it 'returns true when the same source is compressed at different levels' do
      source = 'abcdefghij' * 1_000
      fast = described_class.compress(source, level: Zlib::BEST_SPEED)
      best = described_class.compress(source, level: Zlib::BEST_COMPRESSION)

      expect(described_class.equivalent?(fast, best)).to be true
    end

    it 'returns false for blobs with different payloads' do
      a = described_class.compress('hello')
      b = described_class.compress('world')

      expect(described_class.equivalent?(a, b)).to be false
    end

    it 'returns true for two empty gzip streams' do
      a = described_class.compress('')
      b = described_class.compress('')

      expect(described_class.equivalent?(a, b)).to be true
    end

    it 'returns false for empty vs non-empty payload' do
      a = described_class.compress('')
      b = described_class.compress('data')

      expect(described_class.equivalent?(a, b)).to be false
    end

    it 'compares binary payloads byte-for-byte' do
      payload = (0..255).map(&:chr).join.b
      a = described_class.compress(payload)
      b = described_class.compress(payload)

      expect(described_class.equivalent?(a, b)).to be true
    end

    it 'raises when the first argument is not gzip' do
      valid = described_class.compress('ok')

      expect { described_class.equivalent?('not gzip', valid) }.to raise_error(
        Philiprehberger::GzipKit::Error, 'first argument is not valid gzip data'
      )
    end

    it 'raises when the second argument is not gzip' do
      valid = described_class.compress('ok')

      expect { described_class.equivalent?(valid, 'not gzip') }.to raise_error(
        Philiprehberger::GzipKit::Error, 'second argument is not valid gzip data'
      )
    end

    it 'raises when both arguments are not gzip' do
      expect { described_class.equivalent?('bad', 'data') }.to raise_error(
        Philiprehberger::GzipKit::Error
      )
    end
  end

  describe '.inspect_header' do
    it 'returns header info for valid gzip data' do
      compressed = described_class.compress('Hello')
      header = described_class.inspect_header(compressed)

      expect(header).to be_a(Hash)
      expect(header[:method]).to eq(:deflate)
      expect(header).to have_key(:mtime)
      expect(header).to have_key(:os)
      expect(header).to have_key(:original_name)
      expect(header).to have_key(:comment)
    end

    it 'returns nil for non-gzip data' do
      expect(described_class.inspect_header('not gzip')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.inspect_header(nil)).to be_nil
    end

    it 'returns nil for empty string' do
      expect(described_class.inspect_header('')).to be_nil
    end

    it 'returns nil for truncated gzip data' do
      compressed = described_class.compress('Hello')
      truncated = compressed[0..5]

      expect(described_class.inspect_header(truncated)).to be_nil
    end

    it 'reports mtime as a Time object' do
      compressed = described_class.compress('Hello')
      header = described_class.inspect_header(compressed)

      expect(header[:mtime]).to be_a(Time)
    end

    it 'reports os as an integer' do
      compressed = described_class.compress('Hello')
      header = described_class.inspect_header(compressed)

      expect(header[:os]).to be_a(Integer)
    end

    it 'reports nil for original_name when not set' do
      compressed = described_class.compress('Hello')
      header = described_class.inspect_header(compressed)

      expect(header[:original_name]).to be_nil
    end

    it 'reports nil for comment when not set' do
      compressed = described_class.compress('Hello')
      header = described_class.inspect_header(compressed)

      expect(header[:comment]).to be_nil
    end

    it 'reads header with custom original_name' do
      io_out = StringIO.new
      io_out.binmode
      gz = Zlib::GzipWriter.new(io_out)
      gz.orig_name = 'test.txt'
      gz.write('Hello')
      gz.close

      header = described_class.inspect_header(io_out.string)

      expect(header[:original_name]).to eq('test.txt')
    end

    it 'reads header with custom comment' do
      io_out = StringIO.new
      io_out.binmode
      gz = Zlib::GzipWriter.new(io_out)
      gz.comment = 'test comment'
      gz.write('Hello')
      gz.close

      header = described_class.inspect_header(io_out.string)

      expect(header[:comment]).to eq('test comment')
    end
  end

  describe '.compress_stream and .decompress_stream' do
    it 'roundtrips via streams' do
      original = "Streaming gzip test data!\n" * 200

      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(original), compressed_io)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io)

      expect(decompressed_io.string).to eq(original)
    end

    it 'handles large streaming data' do
      original = 'y' * 500_000

      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(original), compressed_io)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io)

      expect(decompressed_io.string).to eq(original)
    end

    it 'streams with custom compression level' do
      original = "Stream level test.\n" * 300

      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(original), compressed_io, level: Zlib::BEST_SPEED)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io)

      expect(decompressed_io.string).to eq(original)
    end

    it 'handles empty stream' do
      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(''), compressed_io)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io)

      expect(decompressed_io.string).to eq('')
    end
  end

  describe 'chunk_size keyword' do
    it 'roundtrips via streams with a small chunk size on a longer input' do
      original = ('abcdefghij' * 2_000).dup # 20,000 bytes — well above 256 byte chunk
      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(original), compressed_io, chunk_size: 256)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io, chunk_size: 256)

      expect(decompressed_io.string).to eq(original)
    end

    it 'roundtrips via files with a small chunk size' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        output = File.join(dir, 'output.txt')

        content = ('chunked content line.' * 1_500)
        File.write(src, content)

        described_class.compress_file(src, compressed, chunk_size: 256)
        described_class.decompress_file(compressed, output, chunk_size: 256)

        expect(File.read(output)).to eq(content)
      end
    end

    it 'raises ArgumentError when chunk_size is zero on compress_stream' do
      expect do
        described_class.compress_stream(StringIO.new('data'), StringIO.new, chunk_size: 0)
      end.to raise_error(ArgumentError, /chunk_size must be a positive Integer/)
    end

    it 'raises ArgumentError when chunk_size is negative on decompress_stream' do
      expect do
        described_class.decompress_stream(StringIO.new, StringIO.new, chunk_size: -1)
      end.to raise_error(ArgumentError, /chunk_size must be a positive Integer/)
    end

    it 'raises ArgumentError when chunk_size is zero on compress_file' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        File.write(src, 'data')

        expect do
          described_class.compress_file(src, File.join(dir, 'out.gz'), chunk_size: 0)
        end.to raise_error(ArgumentError, /chunk_size must be a positive Integer/)
      end
    end

    it 'raises ArgumentError when chunk_size is negative on decompress_file' do
      Dir.mktmpdir do |dir|
        src = File.join(dir, 'input.txt')
        compressed = File.join(dir, 'input.txt.gz')
        File.write(src, 'data')
        described_class.compress_file(src, compressed)

        expect do
          described_class.decompress_file(compressed, File.join(dir, 'out.txt'), chunk_size: -10)
        end.to raise_error(ArgumentError, /chunk_size must be a positive Integer/)
      end
    end

    it 'raises ArgumentError when chunk_size is not an Integer' do
      expect do
        described_class.compress_stream(StringIO.new('data'), StringIO.new, chunk_size: 1024.5)
      end.to raise_error(ArgumentError, /chunk_size must be a positive Integer/)
    end
  end

  describe '.decompress with stats' do
    it 'returns a string when stats is false' do
      compressed = described_class.compress('Hello')
      result = described_class.decompress(compressed, stats: false)

      expect(result).to be_a(String)
      expect(result).to eq('Hello')
    end

    it 'returns a string when stats is not provided' do
      compressed = described_class.compress('Hello')
      result = described_class.decompress(compressed)

      expect(result).to be_a(String)
      expect(result).to eq('Hello')
    end

    it 'returns a hash with data and ratio when stats is true' do
      original = 'a' * 10_000
      compressed = described_class.compress(original)
      result = described_class.decompress(compressed, stats: true)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:data)
      expect(result).to have_key(:ratio)
      expect(result[:data]).to eq(original)
    end

    it 'calculates ratio as compressed_size / decompressed_size' do
      original = 'a' * 10_000
      compressed = described_class.compress(original)
      result = described_class.decompress(compressed, stats: true)
      expected_ratio = compressed.bytesize.to_f / original.bytesize

      expect(result[:ratio]).to be_within(0.0001).of(expected_ratio)
    end

    it 'returns ratio of 0.0 for empty decompressed output' do
      compressed = described_class.compress('')
      result = described_class.decompress(compressed, stats: true)

      expect(result[:data]).to eq('')
      expect(result[:ratio]).to eq(0.0)
    end

    it 'reports a ratio greater than zero for non-empty input' do
      compressed = described_class.compress('hello, world!')
      result = described_class.decompress(compressed, stats: true)

      expect(result[:ratio]).to be > 0
    end
  end
end
