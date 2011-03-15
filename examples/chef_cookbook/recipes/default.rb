roles = %w[solo util]
if roles.include?(node[:instance_role])
  node[:applications].each do |app, data|

    pidfile = "/data/#{app}/current/tmp/pids/#{app}_resque.pid"

    template "/etc/monit.d/#{app}_resque.monitrc" do
      owner 'root'
      group 'root'
      mode 0644
      source "monitrc.erb"
      variables({
        :app_name => app,
        :pidfile  => pidfile,
        #:max_mem  => "400 MB",
      })
    end

    template "/etc/init.d/#{app}_resque" do
      owner 'root'
      group 'root'
      mode 0744
      source "initd.erb"
      variables({
        :app_name => app,
        :pidfile  => pidfile,
      })
    end

    execute "enable-resque" do
      command "rc-update add #{app}_resque default"
      action :run
      not_if "rc-update show | grep -q '^ *#{app}_resque |.*default'"
    end

    execute "start-resque" do
      command %Q{/etc/init.d/#{app}_resque start}
      creates pidfile
    end

    execute "ensure-resque-is-setup-with-monit" do
      command %Q{monit reload}
    end

  end
end
