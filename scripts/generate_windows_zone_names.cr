#! /usr/bin/env crystal
#
# This script generates the file src/crystal/system/win32/zone_names.cr
# that contains mappings for windows time zone names based on the values
# found in https://github.com/unicode-org/cldr/blob/main/common/supplemental/windowsZones.xml

require "http/client"
require "xml"
require "../src/compiler/crystal/formatter"
require "ecr"

# CLDR-18479 Update CLDR data to TZDB 2025b. (#4593)
WINDOWS_ZONE_NAMES_SOURCE = "https://raw.githubusercontent.com/unicode-org/cldr/f8369ba0795c79f3bac8eb89967eea359f77835e/common/supplemental/windowsZones.xml"
TARGET_FILE               = File.join(__DIR__, "..", "src", "crystal", "system", "win32", "zone_names.cr")
ZONEINFO_ZIP              = File.join(__DIR__, "..", "spec", "std", "data", "zoneinfo.zip")

response = HTTP::Client.get(WINDOWS_ZONE_NAMES_SOURCE)
xml = XML.parse(response.body)
nodes = xml.xpath_nodes("/supplementalData/windowsZones/mapTimezones/mapZone")
entries = nodes.flat_map do |node|
  windows_name = node["other"]
  territory = node["territory"]
  node["type"].split(' ', remove_empty: true).map do |tzdata_name|
    {tzdata_name, territory, windows_name}
  end
end.sort!

iana_to_windows_items = entries.map do |tzdata_name, territory, windows_name|
  {tzdata_name, windows_name}
end.uniq!

ENV["ZONEINFO"] = ZONEINFO_ZIP
windows_zone_names_items = entries.compact_map do |tzdata_name, territory, windows_name|
  next unless territory == "001"
  location = Time::Location.load(tzdata_name)
  next unless location
  time = Time.local(location).at_beginning_of_year
  zone1 = time.zone
  zone2 = (time + 6.months).zone

  # southern hemisphere
  if zone1.offset > zone2.offset
    zone1, zone2 = zone2, zone1
  end

  {windows_name, zone1.name, zone2.name, location.name}
rescue err : Time::Location::InvalidLocationNameError
  pp err
  nil
end

source = ECR.render "#{__DIR__}/windows_zone_names.ecr"
source = Crystal.format(source)
File.write(TARGET_FILE, source)
