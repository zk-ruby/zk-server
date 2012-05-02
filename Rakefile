namespace :yard do
  task :clean do
    rm_rf '.yardoc'
  end

  task :server => :clean do
    sh "yard server --reload"
  end
end

task :clean => 'yard:clean'


