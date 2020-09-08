# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class CLI
    class CheckCommand
      class << self
        def run(args)
          Paramsync::CLI.configure

          mode = if args.include?("--pull")
                   :pull
                 else
                   :push
                 end

          Paramsync.config.sync_targets.each do |target|
            diff = target.diff(mode)
            diff.print_report
            if not diff.any_changes?
              puts "No changes to make for this sync target."
            end
            puts
          end
        end
      end
    end
  end
end
