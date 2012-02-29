# syntactic sugar, and separate ivar.  daemons aren't interactive
When /^I run "([^"]*)" in the background$/ do |cmd|
  run_background(unescape(cmd))
end

Then /^the (output|logfiles) should contain the following lines \(with interpolated \$PID\):$/ do |output_logfiles, partial_output|
  interpolate_background_pid(partial_output).split("\n").each do |line|
    output_or_log(output_logfiles).should include(line)
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
  # now kill the daemon!
  begin
    Process.kill(9, @pid_from_pidfile) if @pid_from_pidfile
  rescue Errno::ESRCH
  end
  #`pkill -9 resque-pool`
end
