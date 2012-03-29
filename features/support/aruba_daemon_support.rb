require 'aruba/cucumber'
require 'aruba/api'
require 'aruba/process'

module Aruba

  module Api

    # this is a horrible hack, to make sure that it's done what it needs to do
    # before we do our next step
    def keep_trying(timeout=10, tries=0)
      puts "Try: #{tries}" if @announce_env
      yield
    rescue RSpec::Expectations::ExpectationNotMetError
      if tries < timeout
        sleep 1
        tries += 1
        retry
      else
        raise
      end
    end

    def run_background(cmd)
      @background = run(cmd)
    end

    def send_signal(cmd, signal)
      announce_or_puts "$ kill -#{signal} #{processes[cmd].pid}" if @announce_env
      processes[cmd].send_signal signal
    end

    def background_pid
      @pid_from_pidfile || @background.pid
    end

    # like all_stdout, but doesn't stop processes first
    def interactive_stdout
      only_processes.inject("") { |out, ps| out << ps.stdout(@aruba_keep_ansi) }
    end

    # like all_stderr, but doesn't stop processes first
    def interactive_stderr
      only_processes.inject("") { |out, ps| out << ps.stderr(@aruba_keep_ansi) }
    end

    # like all_output, but doesn't stop processes first
    def interactive_output
      interactive_stdout << interactive_stderr
    end

    def interpolate_background_pid(string)
      interpolated = string.gsub('$PID', background_pid.to_s)
      announce_or_puts interpolated if @announce_env
      interpolated
    end

    def kill_all_processes!
    #  stop_processes!
    #rescue
    #  processes.each {|cmd,process| send_signal(cmd, 'KILL') }
    #  raise
    end

  end

  class Process
    def pid
      @process.pid
    end
    def send_signal signal
      @process.send :send_signal, signal
    end
  end

end
