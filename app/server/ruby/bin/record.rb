puts #!/usr/bin/env ruby

require "time"

require_relative "../core.rb"
require_relative "../lib/sonicpi/studio"
require_relative "../lib/sonicpi/osc/osc"
require_relative "../lib/sonicpi/server"
require_relative "../lib/sonicpi/util"

#Thread.abort_on_exception=true

include SonicPi::Util

$c = SonicPi::OSC::UDPClient.new("127.0.0.1", 4557)

def dispatch(msg)
  $c.send("/" + msg[:cmd], 0, msg[:val])
end

def run_code(code)
  $c.send("/run-code", 0, code)
end

def transform_url(url)
  gh_prefix = "https://github.com/"
  gist_prefix = "https://gist.github.com/"

  if url.start_with?(gh_prefix)
    url = url.sub(gh_prefix, "https://raw.githubusercontent.com/")
    url = url.sub("/blob/", "/")
  elsif url.start_with?(gist_prefix)
    url = url.sub(gist_prefix, "https://gist.githubusercontent.com/")
    url += "/" unless url.end_with? "/"
    url += "raw"
  end
  return url
end

def fetch(url)
  puts "Fetching: #{url}"
  `curl -s "#{url}"`  # hackoid way of getting content
end


def record(url, secs)
  code = fetch(url)
  code = code.strip

  raise "no code found at: #{url}" if code.size == 0

  puts "Fetched code of length #{code.size} from: #{url} :"
  puts "-----"
  puts code
  puts "-----"

  puts "Recording for #{secs} seconds..."
  dispatch cmd: "start-recording"
  run_code(code)
  sleep secs
  dispatch cmd: "stop-recording"
  dispatch cmd: "stop-all-jobs"
  puts "Done recording..."

  ts = Time.new.iso8601
  filename = "recording-#{ts}.wav"
  path = "/tmp/#{filename}"
  puts "Saving to #{path} ..."
  dispatch cmd: "save-recording", val: path

  puts "Done."
end

first_arg = ARGV[0] or raise "missing required URL"
if first_arg == "stop"
  dispatch cmd: "stop-all-jobs"
  exit
end

raise "first arg must be a url" unless first_arg.start_with? /http(s)?:\/\//
url = first_arg
secs = (ARGV[1] or 15).to_i

puts "url: #{url}"
puts "secs: #{secs}"

url = transform_url(url)
puts "transformed url: #{url}"

record(url, secs)
