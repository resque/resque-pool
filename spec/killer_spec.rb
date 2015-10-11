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
 6472 ?        S      0:00 hald-addon-acpi: listening on acpid socket /var/run/acpid.socket
 6502 ?        Sl     2:51 resque-pool-master[demo]: managing [7028, 7034]
 6511 ?        Ss     0:00 xinetd -stayalive -pidfile /var/run/xinetd.pid
 6539 pts/18   Sl+    0:31 ruby /var/www/shipit/shared/bundle/ruby/2.1.0/bin/rails console
20971 ?        Sl    91:51 resque-1.25.2: Waiting for ecwid
14817 pts/15   Ss     0:00 -bash
16334 ?        Ss     0:00 sshd: foo [priv]
16336 ?        S      0:00 sshd: foo@pts/0
16337 pts/0    Ss     0:00 -bash
16342 pts/7    S+     0:00 /bin/bash /usr/local/bin/console
16480 pts/7    Sl+    0:30 ruby /var/www/foo/shared/bundle/ruby/2.1.0/bin/rails console
16486 pts/0    R+     0:00 ps ax
16800 ?        Sl     5:21 resque-pool-master[demo]: managing [20728, 20734]
17239 pts/19   Ss     0:00 -bash
17407 pts/19   S+     0:00 /bin/bash /usr/local/bin/console
17549 pts/19   Sl+    3:37 ruby /var/www/foo/shared/bundle/ruby/2.1.0/bin/rails console
18027 ?        Ss     0:00 rpc.statd -p 32765 -o 32766
18114 ?        S<sl  15:32 auditd
19536 ?        Sl     2:05 resque-scheduler-4.0.0[production]: Processing Delayed Items
20004 pts/9    Ss     0:00 -bash
20728 ?        Sl   165:24 resque-1.25.2: Waiting for queuea,queueb
20734 ?        Sl   164:55 resque-1.25.2: Waiting for queueb,queuea
20799 pts/10   S+     0:00 /bin/bash /usr/local/bin/console
20959 pts/10   Sl+    0:31 ruby /var/www/foo/shared/bundle/ruby/2.1.0/bin/rails console
20967 ?        Sl   332:07 resque-1.25.2: queuec,queued,*
END

end
