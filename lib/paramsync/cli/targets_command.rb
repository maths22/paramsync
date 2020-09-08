# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class CLI
    class TargetsCommand
      class << self
        def run
          Paramsync::CLI.configure

          Paramsync.config.sync_targets.each do |target|
            if target.name
              puts target.name
            else
              puts "[unnamed target] #{target.region}:#{target.prefix}"
            end
          end
        end
      end
    end
  end
end
