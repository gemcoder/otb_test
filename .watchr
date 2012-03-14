def run_spec(file,name)
  unless File.exist?(file)
    puts "matcher: #{name}"
    puts "#{file} does not exist"
    return
  end

  puts "Running #{file}"
  system "rspec #{file}"
  puts
end

watch("^spec/.*/*_spec.rb") do |match|
  run_spec match[0], 1
end

watch("^lib/(.*).rb") do |match|
  run_spec %{spec/lib/#{match[1]}_spec.rb}, 2
end
