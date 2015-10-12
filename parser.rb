require 'open-uri'
require 'csv'
require 'nokogiri'
require 'ruby-progressbar'
load 'stats.rb'
load 'scan.rb'

Stats.init
Scan.init

class Parser
  include Stats
  include Scan

  def initialize(url)
    Scan.catalog_doc  = Nokogiri::HTML(open(url, "Cookie" => "pgs=500"))
    Scan.catalog_doc.encoding = 'UTF-8'
  end

  def scan_groups
    Scan.scan_groups
  end

  def save
    Scan.catalog.uniq!
    CSV.open("catalog.txt", "w",
             col_sep: "\t",
             encoding: 'UTF-8',
             headers: true,
             converters: :numeric,
             header_converters: :symbol
    ) do |cat|
      Scan.catalog.each do |row|
        cat << row
      end
    end
  end

  def start
    Scan.add_record(Scan.headers)
    Scan.scan_main
    save
    puts "Time spent: ", Time.now - Stats.start
    puts "Total goods: ", Stats.total
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start
