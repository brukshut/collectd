#!/usr/bin/env ruby

##
## passenger.rb collectd plugin
##
require 'optparse'
require 'open3'
require 'crack'
require 'socket'

## METHODS
def server_stats(pass_stats)
  sv_stats = {}
  pass_stats['info']['supergroups']['supergroup']['group'].each do |i|
    ## crack json groups of two value arrays representing hashes like ['k', 'v']
    sv_stats['enabled_process_count']   = i[1].to_i if i[0] == 'enabled_process_count'
    sv_stats['disabling_process_count'] = i[1].to_i if i[0] == 'disabling_process_count' 
    sv_stats['disabled_process_count']  = i[1].to_i if i[0] == 'disabled_process_count' 
    sv_stats['capacity_used']           = i[1].to_i if i[0] == 'capacity_used' 
    sv_stats['get_wait_list_size']      = i[1].to_i if i[0] == 'get_wait_list_size' 
    sv_stats['disable_wait_list_size']  = i[1].to_i if i[0] == 'disable_wait_list_size' 
    sv_stats['processes_being_spawned'] = i[1].to_i if i[0] == 'processes_being_spawned' 
  end
  sv_stats
end

def worker_stats(pass_stats)
  ## initialize a whole bunch of Fixnums
  total_concurrency =
  total_sessions =
  total_cpu =
  total_rss =
  total_pss =
  total_private_dirty =
  total_swap =
  total_real_memory =
  total_vmsize = 0
  ## assumes we have spawned processes
  pass_stats['info']['supergroups']['supergroup']['group']['processes']['process'].each do |i|
    total_concurrency   += i['concurrency'].to_i
    total_sessions      += i['sessions'].to_i
    total_cpu           += i['cpu'].to_i
    total_rss           += i['rss'].to_i
    total_pss           += i['pss'].to_i
    total_private_dirty += i['total_private_dirty'].to_i
    total_swap          += i['swap'].to_i
    total_real_memory   += i['real_memory'].to_i
    total_vmsize        += i['vmsize'].to_i
  end   
  aggr_stats = {
    'concurrency'   => total_concurrency.to_i,
    'sessions'      => total_sessions.to_i,
    'cpu'           => total_cpu.to_i,
    'rss'           => total_rss.to_i,
    'pss'           => total_pss.to_i,
    'private_dirty' => total_private_dirty.to_i,
    'swap'          => total_swap.to_i,
    'real_memory'   => total_real_memory.to_i,
    'vmsize'        => total_vmsize.to_i
  }
  aggr_stats
end

def main
  ## options
  options = Hash.new
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]"
    opts.on('-H', '--hostname [hostname]', String, 'hostname') do |v|
      options[:hostname] = v
    end
    opts.on('-p', '--pool [pool]', String, 'load balancer pool name') do |v|
      options[:pool] = v
    end
    opts.on('-i n', '--interval=n', Integer, 'interval') do |v|
      options[:interval] = v
    end
    opts.on('-h', '--help', 'help') do
      puts opts
      exit
    end
  end
  opt_parser.parse!

  ## defaults
  options[:interval] = ENV['COLLECTD_INTERVAL'] unless options[:interval]
  options[:hostname] = Socket.gethostname unless options[:hostname]
  options[:pool] = 'default' if options[:pool].nil?

  begin
    ## sync stdout to flush to collectd
    $stdout.sync = true
    ## collection loop
    while true do
      start_run = Time.now.to_i
      next_run = start_run + options[:interval].to_i

      ## require sudo privileges
      cmd='/usr/bin/sudo /usr/local/bin/passenger-status --show=xml'
      stdout, stderr, status = Open3.capture3(cmd)
      if stderr.empty?
        pass_stats = Crack::XML.parse(stdout)
        metrics_prefix = "#{options[:hostname]}/passenger"
        begin
          server = server_stats(pass_stats)
          server.each do |k, v|
            puts "PUTVAL #{metrics_prefix}/gauge-server/#{options[:pool]}_#{k} interval=10 #{start_run}:#{v}"
          end
        rescue 
          ## rescue exception here
        end
        begin
          workers = worker_stats(pass_stats)
          workers.each do |k, v|
            puts "PUTVAL #{metrics_prefix}/gauge-workers/#{options[:pool]}_#{k} interval=10 #{start_run}:#{v}"
          end
        rescue
          ## rescue exception here
        end
      else
        ## exit silently if passenger is not running
        ## or if you lack privileges to run command
        ## uncomment the following to debug
        #puts stderr
      end
      while ((time_left = (next_run - Time.now.to_i)) > 0) do
        sleep(time_left)
      end
    end
  end
end

main()
