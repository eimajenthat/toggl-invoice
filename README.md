Toggl-Invoice
==========
A Ruby script to generate invoices based on Toggl timesheets, in HTML, PDF, and TXT.

Disclaimer
----------
I am not affiliated in any way with Toggl, although they seem like nice folks.  If you encounter a bug with this script, it's not their fault.  On the other hand, if you encounter a bug with their application, it's not my fault.  Please route any questions accordingly.

For Toggl bugs: http://support.toggl.com/

For bugs with my script: https://github.com/eimajenthat/toggl-invoice/issues

Requirements
------------
+ Ruby
+ a Toggl account (free or paid)
+ check the Gemfile for more

Setup
-----

```bash
git clone --recursive https://github.com/eimajenthat/toggl-invoice.git
gem install bundler
bundle install --gemfile=toggl-invoice/Gemfile
cp toggl-invoice/config/config.yml.example toggl-invoice/config/config.yml
cp toggl-invoice/config/clients.yml.example toggl-invoice/config/clients.yml
```

Then, edit:

1. `toggl-invoice/config/config.yml` to reflect your company identity.  All fields required, though an empty string would probably be okay.
2. `toggl-invoice/config/clients.yml` with your client's details.

Usage
-----
1. Download a CSV report from Toggl.
2. `cd toggl-invoice`
3. `./toggl-invoice.rb /path/to/report.csv`
4. You're done.  The generated invoice files are saved to the archive/ directory.
5. I like to save my raw CSV there as well (add a date code to the file name so it doesn't overwrite another CSV).  I guess I could have the script do this.  Maybe later.

Notes
-----
+ Right now, you need a CSV export from Toggl for this to work.  They're supposed to be working on a reporting API (https://github.com/toggl/toggl_api_docs/issues/3) but it's not ready yet.  Do the Detailed report, not the Summary.  The summary puts everything in a single line item.  The detailed one gives you each interval.  Toggl-Invoice will combine lines with the same description, and add up the time (the same way the PDF sumamry does).
+ You'll want to setup your config.yml and client.yml before generating invoices.
+ I wrote this for myself, because I needed to generate invoices, not as an example of perfect coding for all to see.  Also, I'm new Ruby, and used this as a chance to learn it better.  Expect rough edges, and feel free to smooth them out.
+ In clients.yml, the key for each client (in the example, client keys are 'Initech', 'Intertrode', and 'John Smith'), should precisely match the client names used in your timesheet CSV.  Spaces are fine.  Quotes do not seem to be required.  Not sure if they're allowed.
+ On Windows, you will to have manually install wkhtmltopdf (to a path without spaces, such as C:/tools/wkhtmltopdf), set the path to wkhtmltopdf.exe in config/pdfkit.rb, and uncomment the `require './config/pdfkit.rb'` line in toggl-invoice.rb. See [Installing wkhtmltopdf](https://github.com/pdfkit/pdfkit/wiki/Installing-WKHTMLTOPDF#windows).
+ The PDF files are generated using PDFKit and wkthmltopdf.  There are a vast array of options to modify how the PDF files is generated.  I picked a set of options which worked well for me, generating nice-looking files, with a small foot print.  However, you may want to tweak them for your needs.  The options are passed to PDFKit around [Line 118 of toggl-invoice.rb](https://github.com/eimajenthat/toggl-invoice/blob/master/toggl-invoice.rb#L118).  I have included a listing from wkhtmltopdf, showing all the available options in [pdfoptions.txt](https://github.com/eimajenthat/toggl-invoice/blob/master/pdfoptions.txt).  If you put together a set of options you feel is objectively superior, feel free to submit a [pull request](https://github.com/eimajenthat/toggl-invoice/compare/).

Forking
-------
This is GitHub, and this is open source software.  You are free to fork, use, and modify the code to your needs.  I would appreciate a pull request if you fix any bugs, or make any changes others might find useful.

Acknowledgements
----------------
Toggl-Invoice uses a number of handy Ruby gems to handle CSVs, PDFs, and HTML templates.  Writing all that myself would be a huge pain, especially the PDF part, which is well beyond my skill level.

The spiffy HTML template used for the invoices comes from: https://github.com/tophermade/sprInvoice

My thanks to TopherMade and the Romulan Star Empire for sharing!

License
-------
Copyright 2013 James Adams

This software is licensed under the MIT license, which you can read here:

[LICENSE](https://github.com/eimajenthat/kashoo-php/blob/master/LICENSE)

This is the same license used by jQuery and a number of open source projects.  My understanding is that it should allow you to use, modify, distribute, or not distribute, the code in pretty much any way you see fit.  If you are in doubt about the license, feel free to contact me.

