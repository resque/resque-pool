require 'aruba/api'
require 'aruba/process'

module Aruba

  module Api

    def run_background(cmd)
      @background = run(cmd)
    end

    def send_signal(cmd, signal)
      announce_or_puts "$ kill -#{signal} #{processes[cmd].pid}" if @announce_env
      processes[cmd].send_signal signal
    end

    def interpolate_background_pid(string)
      interpolated = string.gsub('$PID', @background.pid.to_s)
      announce_or_puts interpolated if @announce_env
      interpolated
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
