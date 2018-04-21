#!/usr/bin/env ruby

##
## pgbouncer_collectd.rb
## pgbouncer collectd plugin 
##
require 'rubygems'
require 'optparse'
require 'socket'
require 'pg'
require 'pp'

def main
  ## options
  options = Hash.new
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]"
    opts.on('-H', '--hostname [hostname]', String, 'pgbouncer hostname') do |v|
      options[:hostname] = v
    end
    opts.on('-p', '--poolname [poolname]', String, 'pgbouncer poolname') do |v|
      options[:poolname] = v
    end
    opts.on('-i n', '--interval=n', Integer, 'interval') do |i|
      options[:interval] = i
    end
    opts.on('-h', '--help', 'help') do
      puts opts
      exit
    end
  end
  opt_parser.parse!

  options[:interval] = ENV['COLLECTD_INTERVAL'] unless options[:interval]
  options[:hostname] = Socket.gethostname unless options[:hostname]

  ## we need backend name
  unless options[:poolname]
    puts opt_parser
    exit
  end

  ## establish connection with database
  ## try catch around connection
  connection = PG::Connection.open(
    :dbname => 'pgbouncer',
    :port => 6543,
    :user => 'statsuser',
    :host => options[:hostname],
    :password => 'statsuserpassword'
  )

  begin
    ## sync stdout to flush to collectd
    $stdout.sync = true

    ## collection loop
    while true do
      ## set reporting hostname
      report_hostname = options[:hostname]
      report_hostname = `/bin/hostname`.chomp if options[:hostname] == 'localhost'

      start_run = Time.now.to_i
      next_run = start_run + options[:interval].to_i

      ## show pools
      result = connection.exec('SHOW POOLS')
      ## only if poolname does not exist
      ## result will have zero rows 
      result.each do |row|
        if options[:poolname] == row['database']
          if row['user'] == 'deploy'
            ## send stats
            ## instance-id/plugin-plugin_instance/type-type_instance
            ## collectd_hostname/pgbouncer/
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/cl_active interval=10 #{start_run}:#{row['cl_active']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/cl_waiting interval=10 #{start_run}:#{row['cl_waiting']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/sv_active interval=10 #{start_run}:#{row['sv_active']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/sv_idle interval=10 #{start_run}:#{row['sv_idle']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/sv_used interval=10 #{start_run}:#{row['sv_used']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/sv_tested interval=10 #{start_run}:#{row['sv_tested']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/sv_login interval=10 #{start_run}:#{row['sv_login']}"
            puts "PUTVAL #{report_hostname}/pgbouncer/gauge-pool/#{options[:poolname]}/maxwait interval=10 #{start_run}:#{row['maxwait']}"
          end
        end
      end
      ## sleep to make the interval
      while((time_left = (next_run - Time.now.to_i)) > 0) do
        sleep(time_left)
      end
    end
  end
end

main()
