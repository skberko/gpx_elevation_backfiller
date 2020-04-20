#!/usr/bin/ruby
require_relative 'lib/gpx_elevation_backfiller'

GPXElevationBackfiller.new.run if $PROGRAM_NAME == __FILE__
