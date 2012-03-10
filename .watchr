def run_spec(spec, dont_clear = false)
	cmd = "bundle exec rspec --backtrace --colour -I. -r spec/spec_helper.rb #{spec}"
	system 'clear' unless dont_clear
	puts "Running #{spec}"
	system cmd
end

def run_all_specs
	system 'clear'
	run_spec "spec", true
end

# Ctrl-C
Signal.trap 'INT' do
  if @interrupted then
    @wants_to_quit = true
    abort("\n")
  else
    puts "Interrupt a second time to quit"
    @interrupted = true
    Kernel.sleep 1.5
  end
end

# Ctrl-\
Signal.trap 'QUIT' do
  puts " --- Running full suite ---\n\n"
  run_all_specs
end

watch("lib/redis_cave_keeper/(.*)\.rb") do |match|
  spec_file = %{spec/#{match[1]}_spec.rb}
  if File.exists?(spec_file)
    run_spec spec_file 
	else
		puts "FILE NOT FOUND: #{spec_file}"
  end
end

watch("spec/.*/*_spec.rb") do |match|
  run_spec match[0]
end



#watch("spec/.*_spec\.rb") do |match|
  #system 'rake rspec'
#end

#watch("lib/.*\.rb") do |match|
  #system 'rake rspec'
#end
