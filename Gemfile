source :rubygems

# gem 'zk', :path => '~/zk'

gem 'rake', '>= 0.9'

group :development do
  gem 'pry'
end

group :test do
  gem 'rspec', '~> 2.9.0'
end

group :docs do
  gem 'yard', '~> 0.7.5'

  platform :mri_19 do
    gem 'redcarpet'
  end
end


# Specify your gem's dependencies in zk-server.gemspec
gemspec
