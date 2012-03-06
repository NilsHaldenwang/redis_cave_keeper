watch("spec/.*_spec\.rb") do |match|
  system 'rake rspec'
end

watch("lib/.*\.rb") do |match|
  system 'rake rspec'
end
