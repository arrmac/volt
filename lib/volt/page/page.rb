require 'opal'

ENV['CLIENT'] = true

require 'opal-jquery'
require 'volt/models'
require 'volt/models/params'
require 'volt/controllers/model_controller'
require 'volt/page/bindings/attribute_binding'
require 'volt/page/bindings/content_binding'
require 'volt/page/bindings/each_binding'
require 'volt/page/bindings/if_binding'
require 'volt/page/bindings/template_binding'
require 'volt/page/bindings/event_binding'
require 'volt/page/template_renderer'
require 'volt/page/reactive_template'
require 'volt/page/document_events'
require 'volt/page/sub_context'
require 'volt/page/targets/dom_target'
require 'volt/page/channel'
require 'volt/router/routes'
require 'volt/models/url'
require 'volt/page/url_tracker'
require 'volt'
require 'volt/benchmark/benchmark'
require 'volt/page/render_queue'
require 'volt/page/tasks'

class Page
  attr_reader :url, :params, :page, :store, :templates, :routes, :render_queue

  def initialize

    # debugger
    puts "------ Page Loaded -------"
    @model_classes = {}
    
    # Run the code to setup the page
    @page = ReactiveValue.new(Model.new)#({}, nil, 'page', @model_classes))
    @store = ReactiveValue.new(Store.new(tasks))#({}, nil, 'store', @model_classes))
    
    @url = ReactiveValue.new(URL.new)
    @params = @url.params
    @url_tracker = UrlTracker.new(self)

    @events = DocumentEvents.new
    @render_queue = RenderQueue.new
    
    # Add event for link clicks to handle all a onclick
    # EventBinding.new(self, )
    
    # Setup escape binding for console
    %x{
      $(document).keyup(function(e) {
        if (e.keyCode == 27) {
          Opal.gvars.page.$launch_console();
        }
      });
      
      $(document).on('click', 'a', function(event) {        
        Opal.gvars.page.$link_clicked($(this).attr('href'));
        event.stopPropagation();
        
        return false;
      });
    }
  end
  
  def tasks
    @tasks ||= Tasks.new(self)
  end
  
  def link_clicked(url)
    # Skip when href == ''
    return if url.blank?

    # Normalize url
    Benchmark.bm(1) do
      @url.parse("http://localhost:3000" + url)
    end
  end
  
  # We provide a binding_name, so we can bind events on the document
  def binding_name
    'page'
  end
  
  def launch_console
    puts "Launch Console"
  end

  def channel
    @channel ||= Channel.new
  end

  def events
    @events
  end
  
  def add_model(model_name)
    # puts "ADD MODEL: #{model_name.inspect} - #{model_name.camelize.inspect}"
    
    @model_classes[["*", "_#{model_name}"]] = Object.const_get(model_name.camelize)
  end

  def add_template(name, template, bindings)
    # puts "Add Template: #{name}\n#{template.inspect}\n#{bindings.inspect}"
    @templates ||= {}
    @templates[name] = {'html' => template, 'bindings' => bindings}
    # puts "Add Template: #{name}"
  end
  
  def add_routes(&block)
    @routes = Routes.new.define(&block)
    @url.cur.router = @routes
  end

  def start
    # Setup to render template
    Element.find('body').html = "<!-- $CONTENT --><!-- $/CONTENT -->"

    main_controller = IndexController.new

    # Setup main page template
    TemplateRenderer.new(DomTarget.new, main_controller, 'CONTENT', 'home/index/index/body')

    # Setup title listener template
    title_target = AttributeTarget.new
    title_target.on('changed') do
      title = title_target.to_html
      `document.title = title;`
    end
    TemplateRenderer.new(title_target, main_controller, "main", "home/index/index/title")
    
    @url_tracker.url_updated(true)
  end
end

$page = Page.new

# Call start once the page is loaded
Document.ready? do
  $page.start
end