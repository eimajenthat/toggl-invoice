#!/usr/bin/env ruby-1.9.3-p125@toggl-invoice

require 'csv'
require 'time'
require 'money'
require 'liquid'
require 'yaml'
require 'pdfkit'

# uncomment the following on Windows and update config/pdfkit.rb with the wkhtmltopdf.exe path
# require './config/pdfkit.rb'

def main

  config = YAML.load_file(File.join(File.dirname(__FILE__),'config','config.yml'))
  invoice = {
    'date' => Date.today.to_s,
    'number' => Time.now.strftime("%Y%m%d"),
    'bill_to' => '',
    'total' => Money.new(0,'USD'),
    'hourly_rate' => Money.new(0,'USD'),
    'header' => ["Description","Hours","Rate","Amount"],
    'bill_from' => config['company'],
    'items' => []
  }
  
  client = nil
  invoice_save = ''

  # Collect Data from User
  # puts "Please enter the client name and address: "
  # begin
  #   addr_in = STDIN.gets.chomp
  #   invoice['bill_to'] << addr_in if not addr_in.empty?
  # end while not addr_in.empty?

  # puts "What is your hourly rate? "
  # invoice['hourly_rate'] = Money.new(STDIN.gets.chomp.to_i*100, "USD")

  # Parse CSV
  # CSV.foreach(ARGV[0], :headers => true) do |row|
    
  #   if (client.nil?)
  #     client = YAML.load_file('config/clients.yml')[row['Client']]
  #     invoice['bill_to'] = client
  #     invoice['hourly_rate'] = Money.new(client['rate']*100, "USD")
  #     invoice_save = "archive/invoice-#{invoice['number']}-#{row['Client'].tr('^A-Za-z0-9', '')}."
  #   end

  #   duration = row['Duration'].split(':').map(&:to_f)
  #   hours = duration[0]+(duration[1]/60)+(duration[2]/3600)
  #   amount = invoice['hourly_rate'] * hours
  #   invoice['total'] += amount
  #   invoice['items'] << [row['Description'],hours.round(2),invoice['hourly_rate'].format,amount.format]
  # end

  csv = CSV.read ARGV[0], :headers => true
  csv.group_by{|row| row['Description']}.values.each do |group|
    if (client.nil?)
      client = YAML.load_file(File.join(File.dirname(__FILE__),'config','clients.yml'))[group.first['Client']]
      invoice['bill_to'] = client
      invoice['hourly_rate'] = Money.new(client['rate']*100, "USD")
      invoice_save = "archive/invoice-#{invoice['number']}-#{group.first['Client'].tr('^A-Za-z0-9', '')}."
    end

    hours = group.map{|r| hmsToFloat(r['Duration'])}.inject(:+)
    amount = invoice['hourly_rate'] * hours
    invoice['total'] += amount
    invoice['items'] << [group.first['Description'],hours.round(2),invoice['hourly_rate'].format,amount.format]
  end

  # Generate Text Invoice
  tt = {
    "name" => invoice['header'],
    "width" => [30,6,6,6],
    "linebetweenrows" => false
  }
  table = TextTable.new(tt)
  table_txt = ''
  invoice['items'].each do |item|
    table_txt << table.printrow(item)
  end
  table_txt << table.printLine


  invoice_txt = <<HERE
INVOICE

#{invoice['bill_from']['name']}
#{invoice['bill_from']['street']}
#{invoice['bill_from']['locality']}

Invoice ##{invoice['number']}
Date: #{invoice['date']}

Bill To:
#{invoice['bill_to']['name']}
#{invoice['bill_to']['street']}
#{invoice['bill_to']['locality']}

#{table_txt}

Total: #{invoice['total'].format}

Thank you for your business.
HERE

  puts invoice_txt
  File.open(invoice_save+'txt', 'w') {|f| f.write(invoice_txt) }

  # Generate HTML Invoice
  template_html = File.open("template/css/new.html").read
  invoice_html = Liquid::Template.parse(template_html).render(invoice)

  File.open(invoice_save+'html', 'w') {|f| f.write(invoice_html) }

  # Generate PDF Invoice
  pdf_options = {
    page_size: 'Letter',
    lowquality: true,
    dpi: 200,
    margin_bottom: 10,
    margin_left: 0,
    margin_right: 0,
    margin_top: 10,
    zoom: 0.8,
    disable_smart_shrinking: true
  }
  kit = PDFKit.new(invoice_html, pdf_options)
  kit.to_file(invoice_save+'pdf')
end

def hmsToFloat(str)
  sign = (str.chr == '-') ? str.slice!(0) : ''
  parts = str.split(':').map(&:to_f)
  (sign+(parts[0]+(parts[1]/60)+(parts[2]/3600)).to_s).to_f
end




#
#  texttable.rb  --  testing tool to output a nicely formatted table.
#
# John Allen, June 2005
#  June 2010 -- Added support for word wrap fields
#

class TextTable
  #
  # tableinfo = Hash.new {
  #    "name" =>  Array(:string),
  #    "width" => Array(:fixnum),
  #    ["linebetweenrows" => Boolean,]
  #    ["hdrlinechar" => "=",]
  #    ["rowlinechar" => "-",]
  #    ["wordwrap" => Boolean]
  # }

  attr_accessor  :names,  :widths, :hdr_print_flg, :lbr_flg, :hdrchar, :linechar, :wordwrap

  @hdr_print_flg = false
  @ldr_flg = false
  @wordwrap = false

  def initialize(tableinfo)
    @names = tableinfo["name"]
    @widths = tableinfo["width"]
    if tableinfo["linebetweenrows"]
      @lbr_flg = true
    end
    if tableinfo["wordwrap"]
      @wordwrap = true
    end
    @hdrchar = tableinfo["hdrlinechar"] || "="
    @linechar = tableinfo["rowlinechar"] || "-"
  end

  def printrow(a)
    # a = Array
    a.map!(&:to_s) # Convert all array elements to string
    buf = ""
    if not @hdr_print_flg
      buf << printHdr()
    end
    buf << "|"
    extra = []
    a.each_with_index do |n,i|
      n ||= ''
      if n.length > @widths[i]        ## check to see if value is bigger than field; chop if so
        b = n.slice(0..(@widths[i] -1))
        extra[i] = n.slice(@widths[i]..-1)
      else
        b = n
      end
      buf << " #{b}#{" "*(@widths[i] - b.length)}|"
    end
    buf << "\n"
    if @wordwrap and not extra.empty?   ## Word Wrap
      eflg = true
      while eflg          ## While stuff to word wrap
        eflg = false
        buf << "|"
        extra.each_with_index do |n,i|
          if not n.nil?
            if n.length > @widths[i]        ## check to see if value is bigger than field; chop if so
              b = n.slice(0..(@widths[i] -1))
              extra[i] = n.slice(@widths[i]..-1)
              eflg = true           ## still more to word wrap!!
            else
              b = n
              extra[i] = nil
            end
            buf << " #{b}#{" "*(@widths[i] - b.length)}|"
          else
            buf << " #{" "*@widths[i]}|"  ## add blank space for non-wordwrap field
          end
        end
        buf << "\n"
      end
    end
    buf << _line(@linechar)  if @lbr_flg
    return buf
  end

  def printHdr
    buf = _line(@hdrchar)
    buf << "|"
    @names.each_with_index do |n,i|
      buf << " #{n}#{" "*(@widths[i] - n.length)}|"
    end
    buf << "\n"
    buf << _line(@hdrchar)
    @hdr_print_flg = true
    return buf
  end

  def printLine
    buf = _line(@linechar)
    return buf
  end

  #-------------------------------------------------------------------------------------------------------#
  private
  #-------------------------------------------------------------------------------------------------------#

  def _line(char)
    b = "+"
    @names.each_with_index do |n,i|
      b << char*@widths[i]
      b << "#{char}+"
    end
    b << "\n"
    return b
  end

end

class Money
  def to_liquid
    format
  end
end

main
