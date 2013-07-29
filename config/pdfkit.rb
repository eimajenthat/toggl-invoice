# config/pdfkit.rb
PDFKit.configure do |config|
  # path to wkhtmltopdf.exe on Windows since wkhtmltopdf-binary gem doesn't work on Windows
  config.wkhtmltopdf = 'c:/tools/wkhtmltopdf/wkhtmltopdf.exe'
end
