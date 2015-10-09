require 'open-uri'
require 'csv'
require 'nokogiri'
require 'digest'
require 'mechanize'

class Parser

  def open_catalog
    if File.exist?("catalog.txt")
      CSV.read("catalog.txt", "r", col_sep: "\t",
              headers: false,
              converters: :numeric,
              header_converters: :symbol).
              map { |row| row.to_a }
    else
      CSV.read("catalog.txt", "w+") 
    end
  end

  @@headers        ||= %w{type, group, pic, name}
  @@depth          ||= 0
  @@col_sep        ||= "\t"

  @@total          ||= 0
  @@total_in_group ||= Hash.new(0)
  @@current_group  ||= ""
  @@wo_pic         ||= 0
  @@pic_size       ||= Hash.new(0)
  @@total_size     ||= 0


  def initialize(url)
    @@catalog ||= open_catalog
    @catalog_doc = Mechanize.new.get(url, "Cookie" => "pgs=500")
    @catalog_doc.encoding = 'windows-1251'
  end

  def download_pic(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/.thumbs/'+pic).read
    end
  end

  def download_item(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/goods/.thumbs/'+pic).read
    end
  end

  def scan_groups
    #puts "-Scanning groups..."
    @@depth += 1
    #puts "***Depth is #{@@depth}"
    group = @catalog_doc.search('#content.bar h1').text
    rows = @catalog_doc.search('.children a')
    rows.each do |row|
      type    = "sub-"*(@@depth-1)+"group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      #puts name
      #id      = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      picture = picture ? picture[0] : '-'
      parser = Parser.new('http://www.a-yabloko.ru'+row['href'])
      add_record([type, group, picture, name])
      parser.scan_groups
    end
    scan_goods if rows.empty?

    @@depth -= 1
  end

  def scan_main
    #puts "Scanning main page..."
    links = scan_footer
    group = "---------"
    rows = @catalog_doc.search('.children a')
    rows.each do |row|
      type    = "group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      #puts name
      @@current_group = name
      #id      = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      download_pic(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-' # если картинки нет - ставим прочерк
      parser = Parser.new('http://www.a-yabloko.ru'+links.shift)
      add_record([type, group, picture, name])
      parser.scan_groups
    end
  end

  # Наличие этого метода само со себе является костылём,
  # спасающим от непонятного бага с кривым скачиванием страницы
  # методом open (да и любым другим методом, пробовал curl и curb - 
  # всё одинаково). Суть проблемы в том, что при скачивании страницы 
  # теряются ссылки на группы - кнопка остаётся, сама ссылка тоже остаётся,
  # но затирается конец ссылки, всё что после последнего слеша.
  # Этот метод выцепляет все эти ссылки из футера страницы.
  # Но оказалось, что там есть две устаревшие ссылки,
  # которые нужно бы исключить из результата:
  # /catalog/340/
  # /catalog/343/
  # 
  def scan_footer
    #puts "--Scanning footer..."
    links = Array.new
    @catalog_doc.search('a.root').each do |row|
      links << row['href']
    end
    bad_links = ["/catalog/340/", "/catalog/343/"]
    links -= bad_links
    links
  end

  def scan_goods
    #puts "---Scanning goods....."
    group = @catalog_doc.search('#content.bar h1').text
    rows = @catalog_doc.search('div.goods .img')
    rows.each do |row|
      type = "Item"
      name = row['title']
      #id = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)'\)" }m)[0]
      if picture.nil? || picture[0] == 'no_img_w280h140.png'
        picture = '-'
        @@wo_pic += 1
      else
        picture = picture[0]
        download_pic(picture)
        @@pic_size[picture] = File.size("pictures/"+picture)
        @@total_size += @@pic_size[picture]
      end
      add_record([type, group, picture, name])
      @@total += 1
      @@total_in_group[@@current_group] += 1
    end
  end

  def add_record(arr)
    @@catalog << arr
    if @@total == 1000
      print_stat
    end
  end

  def print_stat 
    puts "******************Summary by first 1000 goods******************"
    @@total_in_group.each do |group, count|
      pc = (count/@@total.to_f)*100
      puts "#{group}: #{count} items, #{pc}% of total"
    end

    puts "Percent goods with pictures: " + (100*(@@total - @@wo_pic) / (@@total.to_f)).round(1).to_s + "%"

    top_size = @@pic_size.max_by { |pic, size| size }
    puts "Top size image: " + (top_size[0]).to_s + "; size: " + ((top_size[1].to_f)/1024).round(1).to_s + " kB"

    least_size = @@pic_size.min_by { |pic, size| size }
    puts "Least size image: " + (least_size[0]).to_s + "; size: " + ((least_size[1].to_f)/1024).round(1).to_s + " kB"

    average_size = (@@total_size.to_f)/1000/1024
    puts "Average image size: " + average_size.round(1).to_s + " kB"
    save
  end

  def save
    @@catalog.uniq!
    open("tmp.txt", "w")  { |file| file.puts @@catalog.inspect } # DBG 
    CSV.open("catalog.txt", "w", col_sep: "\t", encoding: 'windows-1251', headers: true, converters: :numeric, header_converters: :symbol) do |cat|
      @@catalog.each do |row|
        cat << row
      end
    end
  end

  def start
    add_record(@@headers)
    scan_main
    save
    puts "Total goods: ", @@total
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start
