require 'open-uri'
require 'csv'
require 'nokogiri'

class Parser
  attr_accessor :url, :tag, :doc, :headers, :catalog

  def initialize
    @tag = Hash.new
    @url = 'http://greenalco.ru'
    @tag[:main_category] = '.box-category ul li a'
    @doc = Nokogiri::HTML(open(url))
    @headers = %w(name paramsynonym category currency price discount description briefdescription)
    @catalog = []
  end

  def call
    add_header
    groups = scan_main_page
    groups.each do |group|
      scan_group(group)
    end
  end

  private

  def add_record(arr)
    @catalog << arr
  end

  def add_header
    add_record(@headers)
  end

  def scan_main_page
    scan_menu
  end

  def scan_menu
    groups = Hash.new
    @doc.css(@tag[:main_category]).each do |row|
      groups[row.content] = row['href']
    end

    groups
  end

  def scan_group(group)
  end

  def scan_item(item)
  end
end

Parser.new.call
