# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Philiprehberger::GzipKit do
  it "has a version number" do
    expect(Philiprehberger::GzipKit::VERSION).not_to be_nil
  end

  describe ".compress and .decompress" do
    it "roundtrips a simple string" do
      original = "Hello, gzip world!"
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it "produces output smaller than original for compressible data" do
      original = "a" * 10_000
      compressed = described_class.compress(original)

      expect(compressed.bytesize).to be < original.bytesize
    end

    it "handles an empty string" do
      compressed = described_class.compress("")
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq("")
    end

    it "handles binary data" do
      original = (0..255).map(&:chr).join * 10
      original = original.dup.force_encoding(Encoding::BINARY)
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed.bytes).to eq(original.bytes)
    end

    it "handles large data" do
      original = "x" * 1_000_000
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it "handles multi-byte UTF-8 strings" do
      original = "Hello \u00e9\u00e8\u00ea \u3053\u3093\u306b\u3061\u306f"
      compressed = described_class.compress(original)
      decompressed = described_class.decompress(compressed)

      expect(decompressed.force_encoding(Encoding::UTF_8)).to eq(original)
    end
  end

  describe "compression levels" do
    it "compresses with Zlib::BEST_SPEED" do
      original = "a" * 10_000
      compressed = described_class.compress(original, level: Zlib::BEST_SPEED)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it "compresses with Zlib::BEST_COMPRESSION" do
      original = "a" * 10_000
      compressed = described_class.compress(original, level: Zlib::BEST_COMPRESSION)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it "compresses with Zlib::NO_COMPRESSION" do
      original = "Hello, no compression!"
      compressed = described_class.compress(original, level: Zlib::NO_COMPRESSION)
      decompressed = described_class.decompress(compressed)

      expect(decompressed).to eq(original)
    end

    it "produces smaller output with higher compression" do
      original = "abcdefghij" * 5_000
      fast = described_class.compress(original, level: Zlib::BEST_SPEED)
      best = described_class.compress(original, level: Zlib::BEST_COMPRESSION)

      expect(best.bytesize).to be <= fast.bytesize
    end
  end

  describe ".compress_file and .decompress_file" do
    it "roundtrips a file" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "input.txt")
        compressed = File.join(dir, "input.txt.gz")
        output = File.join(dir, "output.txt")

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

    it "roundtrips a binary file" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "binary.dat")
        compressed = File.join(dir, "binary.dat.gz")
        output = File.join(dir, "binary_out.dat")

        original_bytes = (0..255).map(&:chr).join * 100
        File.binwrite(src, original_bytes)

        described_class.compress_file(src, compressed)
        described_class.decompress_file(compressed, output)

        expect(File.binread(output)).to eq(original_bytes)
      end
    end

    it "roundtrips a file with custom compression level" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "input.txt")
        compressed = File.join(dir, "input.txt.gz")
        output = File.join(dir, "output.txt")

        original_content = "Custom level test.\n" * 500
        File.write(src, original_content)

        described_class.compress_file(src, compressed, level: Zlib::BEST_COMPRESSION)
        described_class.decompress_file(compressed, output)

        expect(File.read(output)).to eq(original_content)
      end
    end
  end

  describe ".compress_stream and .decompress_stream" do
    it "roundtrips via streams" do
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

    it "handles large streaming data" do
      original = "y" * 500_000

      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(original), compressed_io)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io)

      expect(decompressed_io.string).to eq(original)
    end

    it "streams with custom compression level" do
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

    it "handles empty stream" do
      compressed_io = StringIO.new
      compressed_io.binmode
      described_class.compress_stream(StringIO.new(""), compressed_io)

      compressed_io.rewind
      decompressed_io = StringIO.new
      decompressed_io.binmode
      described_class.decompress_stream(compressed_io, decompressed_io)

      expect(decompressed_io.string).to eq("")
    end
  end
end
