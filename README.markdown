##  DataShift Spree

Import and Export Spree E-Commerce models through .xls or CSV  files, including all associations.

Create and assign taxons, properties, shipping, tax categories and more through single spreadsheet.

### Versions

This release has been tested against Spree 3.1

## Installation

Requires datashift.

Add to bundle :

    gem 'datashift'
    gem 'datashift_spree'

Most functionality provided via command line tools, so create a high level .thor file 

thor will search root or lib/tasks so for example you can place it in `lib/tasks/shop.thor`

And then copy in the following

```ruby

# You may/may not need this next line depending on your Rails/thor setup
require File.expand_path('config/environment.rb')

require 'datashift'
require 'datashift_spree'

DataShift::load_commands
DataShift::SpreeEcom::load_commands
```

To check the available tasks run thor list with a search term, for example

```ruby
    bundle exec thor list datashift
    bundle exec thor list datashift_spree
```
To check latest usage information use ```thor help <command>```

for example

```ruby
    bundle exec thor help datashift_spree:load:products
```

### Usage

##### Template Generation

For loading data, probably the first thing you'll want to do is create an Excel template for the model(s) you wish to import. There is a general task `datashift:generate:excel` ( or ```datashift:generate:csv ```) for generating a template for any model.

There are some higher level tasks, specifically for producing the specific template for loading Spree Products

```ruby
thor datashift_spree:template:product -t tmp/product_template.xls
```

To also include all possible associations

```ruby
thor datashift:generate:excel -m Spree::Product --associations -t tmp/full_product_template.xls
```

A large number of example Spreadsheets with headers and comments, can be found in the **spec/fixtures** directory - including .xls and csv versions for simple Products or complex Products with multiple/nested Taxons, Variants, Properties etc 

Excel versions contain column headings with **Comments ** with instructions on supported syntax for each column. 

The same DSL syntax is supported in both Excel and CSV versions.

To get detailed information on the impact/usage of each column see the [Spree guides](https://guides.spreecommerce.org) 

For example to understand the `promotionable` field see . https://guides.spreecommerce.org/user/promotions/


##### Data Import/Export

Once you have data prepared you can import it using task : 

```thor datashift_spree:load:products

  -i, --input=INPUT                            # The import file (.xls or .csv)
  -s, [--sku-prefix=SKU_PREFIX]                # Prefix to add to each SKU before saving Product
  -p, [--image-path-prefix=IMAGE_PATH_PREFIX]  # Prefix to add to image path for importing from disk
  -v, [--verbose], [--no-verbose]              # Verbose logging
  -c, [--config=CONFIG]                        # Configuration file containg defaults or over rides in YAML
  -d, [--dummy], [--no-dummy]                  # Dummy run, do not actually save Image or Product
```

Dummy Run is very useful to drive out any issues without actually impacting the database. All changes are rolled back.

A summary of the import is printed to the console,and incase of errors the datashift log will contain full details.

For example, not setting compulsory fields :

```Save Error : #<ActiveRecord::RecordInvalid: Validation failed: Shipping Category can't be blank, Price can't be blank> on DataShift::LoadObject```

###### Simple Product

**Variant Prices/SKUs**

To assign different SKUs or Prices to each variant, datashift supports two special columns

    variant_price
    variant_sku

These should contain pipe '|' delimited lists of the prices, or SKUs, to assign, to each Variant available, and should therefor **contain exactly the same number of entries as Variants available**.

**N.B** These columns should come AFTER the Variant creation columns, as the Variants must exists at the time these columns are processed.

Example

    variant_price	                 variant_sku

```
171.56|260.44|171.56|260.44	TARR.SFOP424EW0|TARR.SFOP424EW3|TARR.SFOP414EW0|TARR.SFOP414EW3     
119.33|208.23	                MOLE.SFOP140EA0|MOLE.SFOP140EA3
110.00|198.00	                TALL.SFOP140EW0|TALL.SFOP140EW3
54.89|109.78|69.24	        CHET.SFOP128EW3|CHET.SFOP140EW0|CHET.SFOP140EW3
42.22	                        LOST.REDL218EW0
```

###### Creating Association data - Excel or CSV


## Testing

We use RSpec, so tests located in the spec subdirectory.

To test this gem we require an actual Spree store, so when the specs are first run 
a dummy Rails app is created containing a Spree store, whose version we can control in `spec/Gemfile`
so it's easy to change the Spree version and re-run the specs.

It's therefor recommended that all testing be done in spec dir itself, so first cd into spec

Edit `spec/Gemfile` and set the version of Spree you wish to test against and run bundler :

```ruby 
    cd spec
    bundle install
```

When changing Spree versions, you should force a rebuild of a clean sandbox, and removing the Gemfile.lock will 
resolve any funny version issues, so  run:

```ruby 
    cd spec
    rm -rf dummy
    rm -rf Gemfile.lock
```

thor datashift:spree_tasks:build_sandbox


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
