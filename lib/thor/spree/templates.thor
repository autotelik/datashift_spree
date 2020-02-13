module DatashiftSpree

  class Template < Thor

    include DataShift::Logging

    desc "product", "Create a template .xls (Excel) file for loading Products"

    method_option :template, aliases: '-t', default: 'product_template.xls', desc: "Filename for the template"

    def product()
      invoke('datashift:generate:excel', [], defaults)
    end

    desc "full", "Create a template .xls (Excel) file for loading Products and associations"

    method_option :template, aliases: '-t', default: 'product_template.xls', desc:'Filename for the template'

    def full
      pass_options = defaults.merge(assoc: true)

      invoke('datashift:generate:excel', [], pass_options)
    end

    private

    def defaults
      {
        verbose: true,
        model: 'Spree::Product',
        additional_headers: ['price', 'sku'],
        result: options[:template]
      }
    end

  end
end