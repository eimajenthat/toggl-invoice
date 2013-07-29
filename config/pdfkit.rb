# config/pdfkit.rb
PDFKit.configure do |config|
  # path to wkhtmltopdf on Windows since wkhtmltopdf-binary gem doesn't work on Windows
  config.wkhtmltopdf = 'c:/Program Files (x86)/wkhtmltopdf/wkhtmltopdf.exe'
end
