# collectd plugins

Several collectd plugins written in ruby and utilize the `exec` plugin.

## brocade virtual traffic manager

his is a collectd plugin that scrapes statistics from a Brocade VTM load balancer

* plugin: brocade_vtm.rb
* configuration: brocade_vtm.conf

## pgbouncer

Talks to pgbouncer and scrape statistics from pools.

* plugin: passenger.rb
* configuration: passenger.conf

## phusion passenger

Scrape passenger statistics using `passenger-status` utility.

* plugin: passenger.rb
* configuration: passenger.conf

## postgresql

This is a collection of useful queries for keeping tabs on a postgresql database.

* confguration: postgresql.conf

## resque

This is simple resque plugin that utilizes the ruby resque gem to watch queues.

* resque.rb
* resque.conf

