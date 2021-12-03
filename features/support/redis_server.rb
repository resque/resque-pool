# frozen_string_literal: true

# BeforeAll do
Before do
  if !system("which redis-server")
    $stderr.puts '', "** can't find `redis-server` in your path"
    $stderr.puts "** try running e.g: `sudo apt install redis-server` (on Debian or Ubuntu)"
    exit! 1
  end

  $stderr.puts "Starting redis for testing at localhost:9736..."
  if (!system("redis-server #{__dir__}/redis-test.conf"))
    $stderr.puts '', "** couldn't start `redis-server`"
    exit! 1
  end
end

# AfterAll do
After do
  processes = `ps -A -o pid,command | grep [r]edis-test`.split("\n")
  pids = processes.map { |process| process.split(" ")[0] }
  puts "Killing test redis server..."
  pids.each { |pid| Process.kill("TERM", pid.to_i) }
  system("rm -f #{__dir__}/dump.rdb #{__dir__}/dump-cluster.rdb")
end
