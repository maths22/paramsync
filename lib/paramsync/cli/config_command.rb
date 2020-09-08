# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class CLI
    class ConfigCommand
      class << self
        def run
          Paramsync::CLI.configure

          puts " Config file: #{Paramsync.config.config_file}"
          puts "     Verbose: #{Paramsync.config.verbose?.to_s.bold}"
          puts
          puts "Sync target defaults:"
          puts "  Chomp trailing newlines from local files: #{Paramsync.config.chomp?.to_s.bold}"
          puts "  Delete remote keys with no local file: #{Paramsync.config.delete?.to_s.bold}"
          puts
          puts "Sync targets:"

          Paramsync.config.sync_targets.each do |target|
            if target.name
              puts "* #{target.name.bold}"
              print ' '
            else
              print '*'
            end
            puts "   Region: #{target.region}"
            puts "    Local type: #{target.type == :dir ? 'Directory' : 'Single file'}"
            puts "     #{target.type == :dir ? " Dir" : "File"} path: #{target.path}"
            puts "        Prefix: #{target.prefix}"
            puts "       Account: #{target.account}"
            puts "     Autochomp? #{target.chomp?}"
            puts "        Delete? #{target.delete?}"
            if not target.exclude.empty?
              puts "    Exclusions:"
              target.exclude.each do |exclusion|
                puts "      - #{exclusion}"
              end
            end
            puts
          end
        end
      end
    end
  end
end
