require 'open-uri'
require 'csv'
require 'nokogiri'
require 'ruby-progressbar'

class Parser

  $headers        ||= %w{type group pic name}
  if File.exist?("catalog.txt")
    $catalog      ||= CSV.read("catalog.txt", "r",
                                col_sep: "\t",
                                headers: false,
                                converters: :numeric,
                                header_converters: :symbol).map { |row| row.to_a } 
  else
    $catalog      ||= CSV.read("catalog.txt", "w+") 
  end
  $depth          ||= 0
  $col_sep        ||= "\t"
  $total          ||= 0.0
  $total_in_group ||= Hash.new(0.0)
  $current_group  ||= ""
  $start          ||= Time.now
  $wo_pic         ||= 0.0
  $pic_size       ||= Hash.new(0.0)
  $total_size     ||= 0.0
  $progressbar    ||= ProgressBar.create(total: 10850, format: "%t: |%B| %p%% complete. ")

  def initialize(url)
    @catalog_html = open(url, "Cookie" => "pgs=500")
    @catalog_doc  = Nokogiri::HTML(@catalog_html)
    @catalog_doc.encoding = 'UTF-8'
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

  def scan_groups
    $depth += 1
    group = @catalog_doc.css('#content.bar h1').text
    rows = @catalog_doc.css('.children a')
    rows.each do |row|
      type    = "sub-"*($depth-1)+"group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0]
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      picture = picture ? picture[0] : '-'
      parser = Parser.new('http://www.a-yabloko.ru'+row['href'])
      add_record([type, group, picture, name])
      parser.scan_groups
    end
    scan_goods if rows.empty?

    $depth -= 1
  end

  def scan_main
    links = scan_footer
    group = "---------"
    rows = @catalog_doc.css('.children a')
    rows.each do |row|
      type    = "group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0]
      $current_group = name
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
        $wo_pic += 1
      else
        picture = picture[0]
        download_item(picture)
        $pic_size[picture] = File.size("pictures/"+picture)
        $total_size += $pic_size[picture]
      end
      add_record([type, group, picture, name])
      $total += 1
      $total_in_group[$current_group] += 1
      $progressbar.increment
    end
  end

  def add_record(arr)
    $catalog << arr
    if $total == 1000
      print_stat
    end
  end

  def print_stat 
    puts "******************Summary by first 1000 goods******************"
    $total_in_group.each do |group, count|
      pc = (count/$total)*100
      puts "#{group}: #{count} items, #{pc}% of total"
    end

    goods_with_picture = (($total - $wo_pic) / ($total)*100).round(1)
    puts "Percent goods with pictures: #{goods_with_picture} %"

    top_size = $pic_size.max_by { |pic, size| size }
    puts "Top size image: #{top_size[0]}; size: #{((top_size[1])/1024).round(1)} kB"

    least_size = $pic_size.min_by { |pic, size| size }
    puts "Least size image: #{(least_size[0])}; size: #{((least_size[1])/1024).round(1)} kB"

    average_size = $total_size/1000/1024
    puts "Average image size: #{average_size.round(1)} kB"
  end

  def save
    $catalog.uniq!
    CSV.open("catalog.txt", "w",
             col_sep: "\t",
             encoding: 'UTF-8',
             headers: true,
             converters: :numeric,
             header_converters: :symbol) do |cat|
      $catalog.each do |row|
        cat << row
      end
    end
  end

  def start
    add_record($headers)
    scan_main
    save
    puts "Time spent: ", Time.now - $start
    puts "Total goods: ", $total
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start
