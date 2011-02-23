Feature: Basic resque-pool daemon configuration and operation
  To easily manage a pool of resque workers, resque-pool provides a daemon with
  simple configuration.  Static configuration is handled in the
  config/config.yml file and dynamic configuration is handled in the Rakefile.

  Background:
    Given a file named "Rakefile" with:
    """
    require 'resque/pool/tasks'
    """

  Scenario: no config file
    When I run the pool manager as "resque-pool"
    Then the pool manager should report that it has started up
    And the pool manager should report that the pool is empty
    And the pool manager should have no child processes
    When I send the pool manager the "QUIT" signal
    Then the pool manager should finish
    And the pool manager should report that it is finished

  @slow_exit
  Scenario: basic config file
    Given a file named "config/resque-pool.yml" with:
    """
    foo: 1
    bar: 2
    "bar,baz": 3
    """
    When I run the pool manager as "resque-pool"
    Then the pool manager should report that it has started up
    And the pool manager should report that 6 workers are in the pool
    And the pool manager should have 1 "foo" worker child processes
    And the pool manager should have 2 "bar" worker child processes
    And the pool manager should have 3 "bar,baz" worker child processes
    When I send the pool manager the "QUIT" signal
    Then the resque workers should all shutdown
    And the pool manager should finish
    And the pool manager should report that a "foo" worker has been reaped
    And the pool manager should report that a "bar" worker has been reaped
    And the pool manager should report that a "bar,baz" worker has been reaped
    And the pool manager should report that it is finished

  Scenario: daemonized
    Given a directory named "log"
    And a directory named "tmp/pids"
    And a file named "config/resque-pool.yml" with:
    """
    foo: 2
    bar: 4
    "baz,quux": 4
    """
    When I run the pool manager as "resque-pool -d"
    Then the pool manager should record its pid in "tmp/pids/resque-pool.pid"
    And the pool manager should daemonize
    And a file named "log/resque-pool.stdout.log" should exist
    And a file named "log/resque-pool.stderr.log" should exist
    And the pool manager should log that it has started up
    And the pool manager should log that 10 workers are in the pool
    And the pool manager should have 2 "foo" worker child processes
    And the pool manager should have 4 "bar" worker child processes
    And the pool manager should have 4 "baz,quux" worker child processes
    When I send the pool manager the "QUIT" signal
    Then the resque workers should all shutdown
    And the pool manager daemon should finish
    And the pool manager should log that a "foo" worker has been reaped
    And the pool manager should log that a "bar" worker has been reaped
    And the pool manager should log that a "baz,quux" worker has been reaped
    And the pool manager should log that it is finished
