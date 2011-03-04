#!/usr/bin/env ruby

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','lib'))

require 'hexdump'
require 'benchmark'

DATA = ((0..255).map { |b| b.chr }.join) * 10000
OUTPUT = Class.new { def <<(data); end }.new

Benchmark.bm do |b|
  b.report('hexdump (block)') do
    Hexdump.dump(DATA) { |index,hex,print| }
  end

  b.report('hexdump') do
    Hexdump.dump(DATA, :output => OUTPUT)
  end

  b.report('hexdump width=256 (block)') do
    Hexdump.dump(DATA, :width => 256) { |index,hex,print| }
  end

  b.report('hexdump width=256') do
    Hexdump.dump(DATA, :width => 256, :output => OUTPUT)
  end

  b.report('hexdump ascii=true (block)') do
    Hexdump.dump(DATA, :ascci => true) { |index,hex,print| }
  end

  b.report('hexdump ascii=true') do
    Hexdump.dump(DATA, :ascci => true, :output => OUTPUT)
  end
end
