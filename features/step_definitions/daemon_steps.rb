# syntactic sugar, and separate ivar.  daemons aren't interactive
When /^I run "([^"]*)" in the background$/ do |cmd|
  run_background(unescape(cmd))
end

Then /^the output should contain the following lines \(with interpolated \$PID\):$/ do |partial_output|
  interpolate_background_pid(partial_output).split("\n").each do |line|
    all_output.should include(line)
  end
end

When /^I send "([^"]*)" the "([^"]*)" signal$/ do |cmd, signal|
  send_signal(cmd, signal)
end

Then /^the "([^"]*)" process should finish$/ do |cmd|
  # doesn't actually stop... just polls for exit
  processes[cmd].stop
end

Before("@slow_exit") do
  @aruba_timeout_seconds = 10
end

After do
  kill_all_processes!
end
