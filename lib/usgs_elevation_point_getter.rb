# Utils for USGS Elevation Point Query Service: https://nationalmap.gov/epqs/
require 'json'
require 'net/http'

module USGSElevationPointGetter
  # Points should be in format [lat, long],
  # e.g.
  # [[12.34, 45.67], [21.21, 98.98], ...]
  def self.elevations_for_points(points)
    @result = {}

    batch_number = 1
    points.each_slice(50) do |batch_of_points|
      puts "Working on batch ##{batch_number}"

      threads = batch_of_points.map do |point|
        Thread.new do
          lat       = point.first
          long      = point.last
          elevation = elevation_for_lat_long(lat, long)

          @result[point] = elevation
        end
      end

      threads.each(&:join)

      batch_number += 1
    end

    @result
  end

  private

  def self.elevation_for_lat_long(lat, long)
    url = URI(query_url(lat, long))
    raw_usgs_response = Net::HTTP.get(url)
    json_response = JSON.parse(raw_usgs_response)
    elevation = json_response["USGS_Elevation_Point_Query_Service"]["Elevation_Query"]["Elevation"].to_f

    # USGS API returns -1_000_000 for points it cannot find
    elevation = nil if elevation == -1_000_000

    elevation
  rescue => e
    puts e
    nil
  end

  def self.query_url(lat, long, units='Meters')
    # e.g.
    # https://nationalmap.gov/epqs/pqs.php?x=-109.117755890&y=37.849187851&units=Meters&output=json

    base_url     = "https://nationalmap.gov/epqs/pqs.php?"
    long_param   = "x=#{long}"
    lat_param    = "&y=#{lat}"
    units_param  = "&units=#{units}"
    output_param = '&output=json'

    base_url + long_param + lat_param + units_param + output_param
  end
end
