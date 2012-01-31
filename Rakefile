
task :default => :usage

task :usage do
  puts 'Try one of these commands:'
  sh %{rake -T}
end

namespace :coffee do
  desc 'This compiles the Coffee Script files.'
  task :compile do
    sh %{coffee --compile js}
  end

  desc 'This watches the Coffee Script files and compiles them automatically.'
  task :watch do
    sh %{coffee --compile --watch js}
  end
end

namespace :compass do
  desc 'This compiles the Compass (SCSS) files.'
  task :compile do
    sh %{compass compile . --config config.rb}
  end

  desc 'This watches the SCSS files.'
  task :watch do
    sh %{compass watch . --config config.rb}
  end
end

desc 'This watches both the Coffee Script and Compass files.'
multitask :watch => ['coffee:watch',
                     'compass:watch']

require './lib/mdprocessor'
desc 'This compiles some markdown files into the javascript the tutorial reads.'
Tutorial::Content::compile 'tutorial', 'js/docs/tutorial.js', ['js/docs/tutorial.md']

