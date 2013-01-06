##  DataShift Spree

Specific loaders and command line tasks for Spree E-Commerce.

Wiki here : **https://github.com/autotelik/datashift_spree/wiki**

### Features

Import and Export Spree models through .xls or CSV  files, including
all associations and setting configurable defaults or over rides.

High level rake and thor command line tasks for import/export provided.

Specific loaders and command line tasks provided out the box for **Spree E-Commerce**, 
enabling import/export of Product data including creating Variants with different
 count on hands and all associations including Properties/Taxons/OptionTypes and Images.

Loaders can be configured via YAML with over ride values, default values and mandatory column settings.

Many example Spreadsheets/CSV files in spec/fixtures, fully documented with comments for each column.

## Installation

Requires datashift.

Add to bundle :

    gem 'datashift'
    gem 'datashift_spree'

Create a high level .thor file - e.g mysite.thor - in your applications root directory 


```ruby
require 'datashift'
require 'datashift_spree'

DataShift::load_commands
DataShift::SpreeHelper::load_commands
```

To check the available tasks run

    bundle exec thor list datashift

New functionality and options under active development so check latest
usage information via ```thor help <command>``` ... for example

    bundle exec thor help datashift:spree:products

```ruby
Usage:
  thor help datashift:spree:products 

   Populate Spree Product/Variant data from .xls (Excel) or CSV file
```


## License

Copyright:: (c) Autotelik Media Ltd 2012

Author ::   Tom Statter

Date ::     Oct 2012

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
