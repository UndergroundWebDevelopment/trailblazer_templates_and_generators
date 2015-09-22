rails_ui = yes?("Configure for a Rails based UI?")

git :init
git add: ".", commit: %(-m "Initial Commit")

# Install the trailblazer framework:
gem 'trailblazer', github: 'apotonick/trailblazer'
gem 'trailblazer-rails'

# Responders adds support for respond_with and separate responder classes to
# handle different request formats:
gem 'responders'

# Roar provides representers which can parse and render API documents (e.g. 
# JSON, XML, JSON-API) from models:
gem 'roar-rails'

gem_group(:development, :test) do
  # Use rspec for unit tests (instead of Rails default testunit):
  gem 'rspec-rails'
end

# Use the Puma server:
gem 'puma'

after_bundle do
  generate 'responders:install'
  generate 'rspec:install'
end

if rails_ui
  # Cells provides view-controllers, instead of rails default rendering with
  # globals:
  gem 'cells'
  gem 'cells-haml'
  
  # Install bootstrap for front-end styling:
  gem 'bootstrap-sass'
  gem 'bootstrap-sass-extras'

  # Install simple_form, to help with generating and rendering HTML forms:
  gem 'simple_form'

  gem_group(:development, :test) do
    # Install capybara for UI testing:
    gem 'capybara'
  end

  # Include bootstrap javascript in application.js
  insert_into_file "app/assets/javascripts/application.js", "//= require bootstrap-sprockets\n", after: "//= require jquery_ujs\n"

  # Remove default css file and replace with a sass file that immports
  # bootstrap:
  remove_file "app/assets/stylesheets/application.css"

  file "app/assets/stylesheets/application.sass", <<-CODE
@import "bootstrap-sprockets"
@import "bootstrap"

body  
  padding-top: 50px
  CODE

  # Remove the default application layout and replace with a haml/bootstrap
  # layout:
  remove_file "app/views/layouts/application.html.erb"
  file "app/views/layouts/application.html.haml", <<-CODE
!!!
%html
  %head
    %meta{"charset" => "utf-8"}
    %meta{"http-quiv" => "X-UA-Compatible", content: "IE=edge"}
    %meta{"name" => "viewport", content: "width=device-width, initial-scale=1"}
    %title #{app_name}
    = stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track' => true
    = javascript_include_tag 'application', 'data-turbolinks-track' => true
    = csrf_meta_tags
  %body
    %nav.navbar.navbar-inverse.navbar-fixed-top
      .container
        .navbar-header
          %button.navbar-toggle.collapsed{"type" => "button", "data-toggle" => "collapse", "data-target" => "#navbar", "aria-expanded" => "false", "aria-controls" => "navbar"}
            %span.sr-only
              Toggle navigation
            %span.icon-bar
            %span.icon-bar
            %span.icon-bar
          %a.navbar-brand{href: "/"}
            VAL Project
        #navbar.collapse.navbar-collapse
          %ul.nav.navbar-nav
            %li
              %a{href: "/"} Home
    .container
      = yield
  CODE

  after_bundle do
    generate 'simple_form:install', '--bootstrap'
    generate 'bootstrap:install'
    generate 'bootstrap:layout', 'application', 'fixed'
  end
end

# Set the version of ruby in the gemfile, to the currently running version of
# ruby. Ensures that everyone running the code uses the same version of ruby,
# and will set ruby for Heroku (if deploying there).
insert_into_file 'Gemfile', "ruby \"#{RUBY_VERSION}\"", after: "source 'https://rubygems.org'\n" 

# Custom handling for postgres data stores. I like to keep the data files for
# the development database with the app (but not in the git repo, of course!)
db_location = 'vendor/postgresql'

append_file '.gitignore', db_location

file 'bin/local_postgres', <<-CODE
#!/bin/bash
f=`dirname "$0"`
POSTGRESQL_DATA="$f/../#{db_location}"

if [ ! -d $POSTGRESQL_DATA ]; then
  mkdir -p $POSTGRESQL_DATA
  initdb -D $POSTGRESQL_DATA
fi

exec postgres -D $POSTGRESQL_DATA
CODE
run "chmod +x bin/local_postgres"

# Create a procfile compatible with Heroku and/or Foreman:
file 'Procfile', <<-CODE
db: bin/local_postgres
web: rails server Puma
CODE

after_bundle do
  # Initial Migrations:
  with_db do
    ['development', 'test'].each do |env|
      rake "db:create", env: env

      # Only bother running migrations if we've setup any:
      if Dir.exist? "db/migrate"
        rake "db:migrate", env: env
      end
    end
  end

  # Commit changes from the template:
  git add: ".", commit: %(-m "After configuration by template.")
end

def with_db(options = {})
  options[:sleep] ||= 3
  db_pid = fork do
    exec "foreman start db"
  end

  sleep options[:sleep]
  begin
    yield
  ensure
    Process.kill("TERM", db_pid)
  end
end
