def process_should_exist(pid)
  expect { Process.kill(0, pid) }.not_to raise_error
end

def process_should_not_exist(pid)
  expect { Process.kill(0, pid) }.to raise_error(Errno::ESRCH)
end

def grab_worker_pids(count, str)
  # TODO: check output_or_log for #{count} worker started messages"
  pid_regex = (1..count).map { '(\d+)' }.join ', '
  full_regex = /resque-pool-manager\[aruba\]\[\d+\]: Pool contains worker PIDs: \[#{pid_regex}\]/m
  str.should =~ full_regex
  @worker_pids = full_regex.match(str).captures.map {|pid| pid.to_i }
end

def output_or_logfiles_string(report_log)
  case report_log
  when "report", "output"
    "output"
  when "log", "logfiles"
    "logfiles"
  else
    raise ArgumentError
  end
end

def output_or_log(report_log)
  case report_log
  when "report", "output"
    interactive_output
  when "log", "logfiles"
    in_current_dir do
      File.read("log/resque-pool.stdout.log") << File.read("log/resque-pool.stderr.log")
    end
  else
    raise ArgumentError
  end
end

class NotFinishedStarting < StandardError; end
def worker_processes_for(queues)
  children_of(background_pid).select do |pid, cmd|
    raise NotFinishedStarting if cmd =~ /Starting$/
    cmd =~ /^resque-\d+.\d+.\d+: Waiting for #{queues}$/
  end
rescue NotFinishedStarting
  retry
end

def children_of(ppid)
  if RUBY_PLATFORM =~ /darwin/i
    ps = `ps -eo ppid,pid,comm | grep '^ *#{ppid} '`
  else
    ps = `ps -eo ppid,pid,cmd | grep '^ *#{ppid} '`
  end
  ps.split(/\s*\n/).map do |line|
    _, pid, cmd = line.strip.split(/\s+/, 3)
    [pid, cmd]
  end
end

When /^I run the pool manager as "([^"]*)"$/ do |cmd|
  @pool_manager_process = run_background(unescape(cmd))
end

When /^I send the pool manager the "([^"]*)" signal$/ do |signal|
  Process.kill signal, background_pid
  output_logfiles = @pid_from_pidfile ? "logfiles" : "output"
  case signal
  when "QUIT"
    keep_trying do
      step "the #{output_logfiles} should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[aruba][$PID]: QUIT: graceful shutdown, waiting for children
      EOF
    end
  else
    raise ArgumentError
  end
end

Then /^the pool manager should record its pid in "([^"]*)"$/ do |pidfile|
  in_current_dir do
    keep_trying do
      File.should be_file(pidfile)
      @pid_from_pidfile = File.read(pidfile).to_i
      @pid_from_pidfile.should_not == 0
      process_should_exist(@pid_from_pidfile)
    end
  end
end

Then /^the pool manager should daemonize$/ do
  stop_processes!
end

Then /^the pool manager daemon should finish$/ do
  keep_trying do
    process_should_not_exist(@pid_from_pidfile)
  end
end

# nomenclature: "report" => output to stdout/stderr
#               "log"    => output to default logfile

Then /^the pool manager should (report|log) that it has started up$/ do |report_log|
  keep_trying do
    step "the #{output_or_logfiles_string(report_log)} should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[aruba][$PID]: Resque Pool running in test environment
resque-pool-manager[aruba][$PID]: started manager
    EOF
  end
end

Then /^the pool manager should (report|log) that the pool is empty$/ do |report_log|
  step "the #{output_or_logfiles_string(report_log)} should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[aruba][$PID]: Pool is empty
  EOF
end

Then /^the pool manager should (report|log) that (\d+) workers are in the pool$/ do |report_log, count|
  grab_worker_pids Integer(count), output_or_log(report_log)
end

Then /^the resque workers should all shutdown$/ do
  @worker_pids.each do |pid|
    keep_trying do
      process_should_not_exist(pid)
    end
  end
end

Then "the pool manager should have no child processes" do
  children_of(background_pid).size.should == 0
end

Then /^the pool manager should have (\d+) "([^"]*)" worker child processes$/ do |count, queues|
  worker_processes_for(queues).size.should == Integer(count)
end

Then "the pool manager should finish" do
  # assuming there will not be multiple processes running
  stop_processes!
end

Then /^the pool manager should (report|log) that it is finished$/ do |report_log|
  step "the #{output_or_logfiles_string(report_log)} should contain the following lines (with interpolated $PID):", <<-EOF
resque-pool-manager[aruba][$PID]: manager finished
  EOF
end

Then /^the pool manager should (report|log) that a "([^"]*)" worker has been reaped$/ do |report_log, worker_type|
  step 'the '+ output_or_logfiles_string(report_log) +' should match /Reaped resque worker\[\d+\] \(status: 0\) queues: '+ worker_type + '/'
end

Then /^the logfiles should match \/([^\/]*)\/$/ do |partial_output|
  output_or_log("log").should =~ /#{partial_output}/
end

