Feature: Basic resque-pool daemon configuration and operation
  To easily manage a pool of resque workers, resque-pool provides a daemon with
  simple configuration.  Static configuration is handled in the
  config/config.yml file and dynamic configuration is handled in the Rakefile.

  Background:
    Given a file named "Rakefile" with:
    """
    require 'resque/pool/tasks'
    """

  Scenario: basic Rakefile, no config file
    When I run the pool manager as "resque-pool"
    Then the pool manager should start up
    And the pool manager should report to stdout that the pool is empty
    And the pool manager should have no child processes
    When I send the pool manager the "QUIT" signal
    Then the pool manager should finish
    And the pool manager should report to stdout that it is finished

  @slow_exit
  Scenario: basic config file
    Given a file named "config/resque-pool.yml" with:
    """
    foo: 2
    bar: 2
    "bar,baz": 2
    """
    When I run "resque-pool" in the background
    Then the output should contain the following lines (with interpolated $PID):
      """
      resque-pool-manager[$PID]: Resque Pool running in development environment
      resque-pool-manager[$PID]: started manager
      """
    Then the output should match:
      """
      resque-pool-manager\[\d+\]: Pool contains worker PIDs: \[\d+, \d+, \d+, \d+, \d+, \d+\]
      """
    When I send "resque-pool" the "QUIT" signal
    Then the "resque-pool" process should finish
    And the output should match /Reaped resque worker\[\d+\] \(status: 0\) queues: foo/
    And the output should match /Reaped resque worker\[\d+\] \(status: 0\) queues: bar/
    And the output should match /Reaped resque worker\[\d+\] \(status: 0\) queues: bar,baz/
    And the output should contain the following lines (with interpolated $PID):
      """
      resque-pool-manager[$PID]: QUIT: graceful shutdown, waiting for children
      resque-pool-manager[$PID]: manager finished
      """
