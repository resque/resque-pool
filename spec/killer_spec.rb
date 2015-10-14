require 'spec_helper'
require 'resque/pool/killer'

describe Resque::Pool::Killer do
  subject(:killer) { Resque::Pool::Killer.new }
  describe "parse pids from output" do
    it "returns the first column, as integer, for resque pool processes" do
      pids = killer.parse_pids_from_output(PS_OUTPUT)
      pids.should match_array [6502, 16800]
    end
  end

  PS_OUTPUT= <<END
 6472 hald-addon-acpi: listening on acpid socket /var/run/acpid.socket
 6502 resque-pool-master[demo]: managing [7028, 7034]
 6511 xinetd -stayalive -pidfile /var/run/xinetd.pid
 6539 ruby /var/www/shipit/shared/bundle/ruby/2.1.0/bin/rails console
20971 resque-1.25.2: Waiting for ecwid
14817 -bash
16334 sshd: foo [priv]
16336 sshd: foo@pts/0
16337 -bash
16342 /bin/bash /usr/local/bin/console
16480 ruby /var/www/foo/shared/bundle/ruby/2.1.0/bin/rails console
16486 ps ax
16800 resque-pool-master[demo]: managing [20728, 20734]
17239 -bash
17407 /bin/bash /usr/local/bin/console
17408 grep resque-pool-master
17549 ruby /var/www/foo/shared/bundle/ruby/2.1.0/bin/rails console
18027 rpc.statd -p 32765 -o 32766
18114 auditd
19536 resque-scheduler-4.0.0[production]: Processing Delayed Items
20004 -bash
20728 resque-1.25.2: Waiting for queuea,queueb
20734 resque-1.25.2: Waiting for queueb,queuea
20799 /bin/bash /usr/local/bin/console
20959 ruby /var/www/foo/shared/bundle/ruby/2.1.0/bin/rails console
20967 resque-1.25.2: queuec,queued,*
END

end
