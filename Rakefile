
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

