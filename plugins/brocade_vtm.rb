#!/usr/bin/env ruby

##
## brocade_vtm.rb
## brocade virtual traffic manager collectd plugin
##
require 'optparse'
require 'rest-client'
require 'json'
require 'resolv'
require 'yaml'
require 'pp'
require 'socket'

## METHODS

## get virtualserver stats
def fetch_virtualserver_stats(url_prefix, vs)
  url = "#{url_prefix}/api/tm/3.3/status/local_tm/statistics/virtual_servers/#{vs}"
  begin
    response = get_response(url)
    vs_stats = JSON.parse(response.body)
    vs_stats['statistics']
  rescue => e
    e.response 
  end
end

## get pool stats
def fetch_pool_stats(url_prefix, pool)
  url = "#{url_prefix}/api/tm/3.3/status/local_tm/statistics/pools/#{pool}"
  state = { 'alive' => 1, 'dead' => 2, 'unknown' => 3 }
  begin
    response = get_response(url)
    pool_stats = JSON.parse(response.body) 
    pool_stats['statistics']['state'] = state[pool_stats['statistics']['state']]
    pool_stats['statistics']
  rescue => e
    e.response 
  end
end

def fetch_node_stats(url_prefix, hostname, pool)
  #node_ip = Socket::getaddrinfo(Socket.gethostname,"echo",Socket::AF_INET)[0][3]
  node_ip = Resolv.getaddress(hostname)
  state = { 'alive' => 1, 'dead' => 2, 'unknown' => 3 }
  url = "#{url_prefix}/api/tm/3.3/status/local_tm/statistics/nodes/per_pool_node/#{pool}-#{node_ip}:80"
  begin
    response = get_response(url)
    node_stats = JSON.parse(response.body) 
    node_stats['statistics']['state'] = state[node_stats['statistics']['state']]
    node_stats['statistics']
  rescue => e
    e.response 
  end
end

def get_response(url)
  response = RestClient::Request.execute(
    :url => url, 
    :method => :get, 
    :verify_ssl => false, 
    :headers => {'Host' => 'steelapp.atlanticmetro.net'}
  )
  response
end

def clean_name(name)
  clean_name = name.gsub(/(\.|-)/, '_')
  clean_name
end

## END METHODS

## MAIN

## credentials

## options
options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [OPTIONS]"
  opts.on('-H', '--hostname [hostname]', String, 'hostname') do |v|
    options[:hostname] = v
  end
  opts.on('-i n', '--interval=n', Integer, 'interval') do |v|
    options[:interval] = v
  end
  opts.on('-p', '--pool=name', 'pool name') do |v|
    options[:pool] = v
  end
  opts.on('-n', '--node', TrueClass, 'if true, provide node stats only') do |v|
    options[:node] = true
  end
  opts.on('-v', '--virtual-server=name', 'virtual server') do |v|
    options[:vs] = v
  end
  opts.on('-h', '--help', 'help') do
    puts opts
    exit
  end
end
opt_parser.parse!

## some default options
options[:node] = false unless options[:node]
options[:hostname] = Socket.gethostname unless options[:hostname]
unless options[:vs] or options[:pool]
  puts opt_parser
  exit
end

## our metrics path
username = 'temonitor'
password = 'PreHeavEd5'
url_prefix = "https://#{username}:#{password}@10.0.0.5:9070"
metrics_prefix = "#{options[:hostname]}/brocade-vtm"

begin
  ## sync stdout to flush to collectd
  $stdout.sync = true
  ## collection loop
  while true do
    start_run = Time.now.to_i
    next_run = start_run + options[:interval].to_i
    ## if we want vs stats
    if options[:vs]
      vs_name = clean_name(options[:vs])
      vs_stats = fetch_virtualserver_stats(url_prefix, options[:vs])
      vs_stats.each do |k, v|     
        next if k =~ /(protocol|port)/ 
        ## "protocol"=>"http",
        ## "bytes_in"=>28071450308574,
        ## "bytes_in_hi"=>6535,
        ## "bytes_in_lo"=>3839029214,
        ## "bytes_out"=>115048586844609,
        ## "bytes_out_hi"=>26786,
        ## "bytes_out_lo"=>3592853953,
        ## "cert_status_requests"=>4776008,
        ## "cert_status_responses"=>0,
        ## "connect_timed_out"=>529052,
        ## "connection_errors"=>0,
        ## "connection_failures"=>0,
        ## "current_conn"=>355,
        ## "data_timed_out"=>7973,
        ## "direct_replies"=>341991,
        ## "discard"=>16779,
        ## "gzip"=>0,
        ## "gzip_bytes_saved"=>0,
        ## "gzip_bytes_saved_hi"=>0,
        ## "gzip_bytes_saved_lo"=>0,
        ## "http_cache_hit_rate"=>0,
        ## "http_cache_hits"=>0,
        ## "http_cache_lookups"=>0,
        ## "http_rewrite_cookie"=>0,
        ## "http_rewrite_location"=>0,
        ## "keepalive_timed_out"=>171976728,
        ## "max_conn"=>6715,
        ## "max_duration_timed_out"=>0,
        ## "port"=>443,
        ## "processing_timed_out"=>0,
        ## "protocol"=>"http",
        ## "sip_rejected_requests"=>0,
        ## "sip_total_calls"=>0,
        ## "total_conn"=>2088224021,
        ## "total_dgram"=>0,
        ## "udp_timed_out"=>0
        k =~ /_conn/ ? type = 'gauge' : type = 'counter'
        puts "PUTVAL #{metrics_prefix}-vs/#{type}-#{vs_name}/#{k} interval=#{options[:interval]} #{start_run}:#{v}"
      end
    end
    ## if we want pool stats
    if options[:pool] and options[:node] == false
      pool_name = clean_name(options[:pool])
      pool_stats = fetch_pool_stats(url_prefix, options[:pool]) 
      pool_stats.each do |k, v|
        next if k =~ /(algorithm|persistence|nodes)/ 
        ## some of these are counters, some are gauges
        ## "algorithm"=>"leastConnections",
        ## "bytes_in"=>50585400062858,
        ## "bytes_in_hi"=>11777,
        ## "bytes_in_lo"=>3570217866,
        ## "bytes_out"=>13388238811179,
        ## "bytes_out_hi"=>3117,
        ## "bytes_out_lo"=>825749547,
        ## "conns_queued"=>0,
        ## "disabled"=>0,
        ## "draining"=>0,
        ## "max_queue_time"=>0,
        ## "mean_queue_time"=>0,
        ## "min_queue_time"=>0,
        ## "nodes"=>34,
        ## "persistence"=>"none",
        ## "queue_timeouts"=>0,
        ## "session_migrated"=>0,
        ## "state"=>"active",
        ## "total_conn"=>1152812688}
        k =~ /(queue|disabled|draining|session_migrated)/ ? type = 'gauge' : type = 'counter'
        puts "PUTVAL #{metrics_prefix}-pool/#{type}-#{pool_name}/#{k} interval=#{options[:interval]} #{start_run}:#{v}"
      end
    end
    ## if we want node stats
    if options[:pool] and options[:node] == true
      node_stats = fetch_node_stats(url_prefix, options[:hostname], options[:pool]) 
      pool_name = clean_name(options[:pool])
      node_stats.each do |k, v|
        next if k == 'node_port'
        ## some of these are counters, some are gauges
        k =~ /((idle|current)_conn|response|state|current|idle)/ ? type = 'gauge' : type = 'counter'
        puts "PUTVAL #{metrics_prefix}-node/#{type}-#{pool_name}/#{k} interval=10 #{start_run}:#{v}"
      end
    end

    while ((time_left = (next_run - Time.now.to_i)) > 0) do
      sleep(time_left)
    end
  end
end

## END MAIN
