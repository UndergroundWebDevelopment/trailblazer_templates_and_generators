git :init
git add: ".", commit: %(-m "Initial Commit")

# Install the trailblazer framework:
gem 'trailblazer', github: 'apotonick/trailblazer'
gem 'trailblazer-rails'

# Roar provides representers which can parse and render API documents (e.g. 
# JSON, XML, JSON-API) from models:
gem 'roar-rails'

# Use the Puma server:
gem 'puma'

gem_group(:development, :test) do
  # Use rspec for unit tests (instead of Rails default testunit):
  gem 'rspec-rails'
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

application <<-CODE
  config.generators.stylesheets = false
  config.generators.javascripts = false
  config.generators.helper      = false
CODE

after_bundle do
  generate 'rspec:install'

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
