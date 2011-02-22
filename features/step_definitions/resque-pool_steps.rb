When /^I run the pool manager as "([^"]*)"$/ do |cmd|
  @pool_manager_process = run_background(unescape(cmd))
  sleep 1
end

When /^I send the pool manager the "([^"]*)" signal$/ do |signal|
  @pool_manager_process.send_signal signal
  case signal
  when "QUIT"
    Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: QUIT: graceful shutdown, waiting for children
    EOF
  end
end

Then "the pool manager should start up" do
  Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: Resque Pool running in development environment
resque-pool-manager[$PID]: started manager
  EOF
end

Then "the pool manager should report to stdout that the pool is empty" do
  Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: Pool is empty
  EOF
end

Then "the pool manager should have no child processes" do
  announce "need to check ps output"
end

Then "the pool manager should finish" do
  # assuming there will not be multiple processes running
  processes.each { |cmd, p| p.stop }
end

Then "the pool manager should report to stdout that it is finished" do
  Then "the output should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[$PID]: manager finished
  EOF
end
