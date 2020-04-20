require 'nokogiri'
require 'optparse'

require_relative 'usgs_elevation_point_getter'

class GPXElevationBackfiller
  attr_accessor :destructive, :filenames

  def run
    parse_options(ARGV)

    filenames.each do |filename|
      backfill_single_file(filename, destructive)
    end

    puts "\nBackfilled:\n#{filenames.join("\n")}"
  end

  def parse_options(argv)
    parser = OptionParser.new do |opts|
      file = File.basename($PROGRAM_NAME)
      opts.banner = "Usage: #{file} [options]\n\nOptions:"

      opts.on("-f", "--files [FILES]", Array, "Provide GPX files to backfill with elevation data") do |files|
        self.filenames = files
      end

      opts.on("-d", "--destructive", "Modify existing files in place") do
        self.destructive = true
      end
    end

    parser.parse(argv)
  end

  def backfill_single_file(gpx_file_path, destructive=false)
    puts "Backfilling #{gpx_file_path}\n\n"

    doc = Nokogiri::XML(open(gpx_file_path), &:noblanks)
    trackpoint_elements = doc.xpath('//xmlns:trkpt')

    all_points = []
    trackpoint_elements.each do |trkpt|
      lat  = trkpt.xpath('@lat').to_s.to_f
      long = trkpt.xpath('@lon').to_s.to_f

      elevation = if elevation = trkpt.css('ele').any?
        trkpt.css('ele').first.inner_html.to_f
      else
        nil
      end

      all_points << {lat: lat, long: long, elevation: elevation}
    end

    points_to_backfill = all_points.select { |point| point[:elevation].nil? }

    return unless points_to_backfill.any?

    lat_longs_to_backfill = points_to_backfill.map { |point| [point[:lat], point[:long]] }
    usgs_elevation_data = USGSElevationPointGetter.elevations_for_points(lat_longs_to_backfill)

    trackpoint_elements.each do |trkpt|
      next if trkpt.css('ele').any?

      lat  = trkpt.xpath('@lat').to_s.to_f
      long = trkpt.xpath('@lon').to_s.to_f
      usgs_elevation_data_key = [lat, long]

      return unless elevation = usgs_elevation_data[usgs_elevation_data_key]

      trkpt.add_child("<ele>#{elevation}</ele>")
    end

    if destructive
      File.write(gpx_file_path, doc)
    else
      new_file_path =  gpx_file_path.split('.gpx').first + '_elevation_corrected.gpx'
      File.open(new_file_path, 'w') { |file| file.write(doc) }
    end
  end
end
