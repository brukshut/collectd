#!/usr/bin/env ruby

##
## resque.rb
## resque collectd plugin 
##
require 'optparse'
require 'resque'
require 'socket'

module Kernel
  def suppress_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    result = yield
    $VERBOSE = original_verbosity
    return result
  end
end

def main
  ## options
  options = Hash.new
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]"
    opts.on("-r hostname", '--redis-host=hostname', 'redis hostname') do |v|
      options[:redis_host] = v
    end
    opts.on('-i n', '--interval=n', Integer, 'interval') do |i|
      options[:interval] = i
    end
    opts.on("-q name", "--queue=name", "queue name, or all") do |v|
      options[:queue] = v
    end
    opts.on('-h', '--help', 'help') do
      puts opts
      exit
    end
  end
  opt_parser.parse!

  unless options[:queue]
    puts opt_parser 
    exit
  end
  options[:interval] = ENV['COLLECTD_INTERVAL'] if options[:interval].nil?
  options[:redis_host] = 'redis' if options[:redis_host].nil?
  hostname = Socket.gethostname 

  ## establish connection with database
  Resque.redis = Redis::new(
    :host => options[:redis_host],
    :port => 6379
  )
  begin
    ## sync stdout to flush to collectd
    $stdout.sync = true
    ## collection loop
    while true do
      start_run = Time.now.to_i
      next_run = start_run + options[:interval].to_i
      Resque.redis.queue_names.each do |name|
        puts "PUTVAL #{hostname}/resque/gauge-queue/#{name} interval=#{options[:interval]} #{start_run}:#{Resque.redis.queue_size(name)}"
      end

      ## sleep to make the interval
      while((time_left = (next_run - Time.now.to_i)) > 0) do
        sleep(time_left)
      end
    end
  end
end

main()
