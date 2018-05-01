##  DataShift Spree

Specific loaders and command line tasks for Spree E-Commerce.

Wiki here : **https://github.com/autotelik/datashift_spree/wiki**

### Versions

This release has been tested against Spree 3.1

## Installation

Requires datashift.

Add to bundle :

    gem 'datashift'
    gem 'datashift_spree'

Create a high level .thor file (thor will search root or lib/tasks) so for example `lib/tasks/shop.thor`

```ruby
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

New functionality and options under active development so check latest
usage information via ```thor help <command>``` ... for example

```ruby
    bundle exec thor help datashift_spree:load:products
```

### Features

Template Generation

You can create Excel templates of models through the task `datashift:generate:excel`

For example to create a template for loading Products, including all associations

```ruby
datashift:generate:excel -m Spree::Product --assoc -r tmp/product_template.xls
```

Import and Export Spree models through .xls or CSV  files, including
all associations and setting configurable defaults or over rides.

High level thor command line tasks for import/export provided.

Specific loaders and command line tasks provided out the box for **Spree E-Commerce**, 
enabling import/export of Product data including creating Variants with different
 count on hands and all associations including Properties/Taxons/OptionTypes and Images.

Loaders can be configured via YAML with over ride values, default values and mandatory column settings.

Many example Spreadsheets/CSV files in spec/fixtures, fully documented with comments for each column.


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
