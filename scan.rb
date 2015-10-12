require 'csv'
require 'nokogiri'
load 'stats.rb'

Stats.init

module Scan
  class << self
    attr_accessor :depth, :catalog, :headers, :catalog_doc

    def init
      @headers ||= %w(type group pic name)
      if File.exist?('catalog.txt')
        @catalog ||= CSV.read('catalog.txt', 'r',
                              col_sep: "\t",
                              headers: false,
                              header_converters: :symbol,
                              converters: :numeric
        ).map(&:to_a)
      else
        @catalog ||= CSV.read('catalog.txt', 'w+') 
      end
      @depth ||= 0
    end

    def scan_groups
      @depth += 1
      group = @catalog_doc.css('#content.bar h1').text
      rows = @catalog_doc.css('.children a')
      rows.each do |row|
        type    = "sub-"*(@depth-1)+"group"
        name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0]
        picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
        picture = picture ? picture[0] : '-'
        parser = Parser.new('http://www.a-yabloko.ru'+row['href'])
        add_record([type, group, picture, name])
        parser.scan_groups
      end
      scan_goods if rows.empty?

      @depth -= 1
    end

    def scan_main
      links = scan_footer
      group = "---------"
      rows = @catalog_doc.css('.children a')
      rows.each do |row|
        type    = "group"
        name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0]
        Stats.current_group = name
        picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
        download_group(picture[0]) unless picture.nil?
        picture = picture ? picture[0] : '-'
        parser = Parser.new('http://www.a-yabloko.ru'+links.shift)
        add_record([type, group, picture, name])
        parser.scan_groups
      end
    end

    def scan_footer
      links = Array.new
      @catalog_doc.css('a.root').each do |row|
        links << row['href']
      end
      bad_links = ["/catalog/340/", "/catalog/343/"]
      links -= bad_links
      links
    end

    def scan_goods
      group = @catalog_doc.css('#content.bar h1').text
      rows = @catalog_doc.css('div.goods .img')
      rows.each do |row|
        type = "Item"
        name = row['title']
        picture = row.to_s.scan(%r{thumbs/(.*)'\)" }m)[0]
        if picture.nil? || picture[0] == 'no_img_w280h140.png'
          picture = '-'
          Stats.wo_pic += 1
        else
          picture = picture[0]
          download_item(picture)
          Stats.pic_size[picture] = File.size("pictures/"+picture)
          Stats.total_size += Stats.pic_size[picture]
        end
        add_record([type, group, picture, name])
        Stats.total += 1
        Stats.total_in_group[Stats.current_group] += 1
        Stats.progressbar.increment
      end
    end

    def download_group(pic)
      open('pictures/'+pic, 'wb') do |file|
        file << open('http://www.a-yabloko.ru/storage/catalog/.thumbs/'+pic).read
      end
    end

    def download_item(pic)
      open('pictures/'+pic, 'wb') do |file|
        file << open('http://www.a-yabloko.ru/storage/catalog/goods/.thumbs/'+pic).read
      end
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

    def add_record(arr)
      Scan.catalog << arr
      if Stats.total == 1000
        Stats.print_stat
        save
      end
    end

  end
end

