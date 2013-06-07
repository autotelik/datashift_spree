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

To check the available tasks run thor list with a search term, for example

```ruby
    bundle exec thor list datashift
    bundle exec thor list datashift_spree
```

New functionality and options under active development so check latest
usage information via ```thor help <command>``` ... for example

```ruby
    bundle exec thor help datashift_spree:load:products
```

Will print out usage and latest options like ...

```ruby
Usage:
  thor datashift_spree:load:products -i, --input=INPUT

Options:
  -i, --input=INPUT                            # The import file (.xls or .csv)
  -s, [--sku-prefix=SKU_PREFIX]                # Prefix to add to each SKU before saving Product
  -p, [--image-path-prefix=IMAGE_PATH_PREFIX]  # Prefix to add to image path for importing from disk
  -v, [--verbose]                              # Verbose logging
  -c, [--config=CONFIG]                        # Configuration file containg defaults or over rides in YAML
  -d, [--dummy]                                # Dummy run, do not actually save Image or Product


   Populate Spree Product/Variant data from .xls (Excel) or CSV file
```

## Testing

There are a number of specs to test this gem, located in the spec subdirectory.

To properly test this gem we require an actual Spree store, so when the specs are first run 
we create a sandbox Rails app, containing a Spree store, whose version we can control in spec/Gemfile

It's therefor recommended that all testing be done in spec dir itself, so first cd into spec

Define the version of Spree to test against, in the Gemfile, then run

```ruby 
    cd spec
    bundle install
```

If changing Spree versions, it's best to force a rebuild of a clean sandbox, and often removing Gemfile.lock will resolve any funny version issues,
 so  run:

```ruby 
    cd spec
    rm -rf sandbox
    rm -rf Gemfile.lock

Change Gemfile versions and run

```ruby 
    bundle install
```
 
The next time you run rspec the sandbox will be regenerated using the latest versions of Rails/Spree specified in your Gemfile

```ruby 
    bundle exec rspec -c .
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
