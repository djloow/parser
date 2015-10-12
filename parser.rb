require 'open-uri'
require 'csv'
require 'nokogiri'
load 'stats.rb'
load 'scan.rb'

Stats.init
Scan.init

class Parser
  include Stats
  include Scan

  def initialize(url)
    Scan.catalog_doc = Nokogiri::HTML(open(url, 'Cookie' => 'pgs=500'))
    Scan.catalog_doc.encoding = 'UTF-8'
  end

  def scan_groups
    Scan.scan_groups
  end

  def add_header
    Scan.add_record(Scan.headers)
  end

  def start
    add_header
    Scan.scan_main
    Scan.save
    puts 'Time spent: ', Time.now - Stats.start
    puts 'Total goods: ', Stats.total
  end
end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start
