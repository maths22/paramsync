# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class CLI
    class PushCommand
      class << self
        def run(args)
          Paramsync::CLI.configure
          STDOUT.sync = true

          Paramsync.config.sync_targets.each do |target|
            diff = target.diff(:push)

            diff.print_report

            if not diff.any_changes?
              puts
              puts "Everything is in sync. No changes need to be made to this sync target."
              next
            end

            puts
            puts "Do you want to push these changes?"
            print "  Enter '" + "yes".bold + "' to continue: "
            answer = args.include?('--yes') ? 'yes' : gets.chomp

            if answer.downcase != "yes"
              puts
              puts "Push cancelled. No changes will be made to this sync target."
              next
            end

            puts
            diff.items_to_change.each do |item|
              case item.op
              when :create
                print "CREATE".bold.green + " " + item.ssm_key
                begin
                  target.ssm.put_parameter(
                    name: item.ssm_key,
                    value: item.local_content[0],
                    type: item.local_content[1] ? 'SecureString' : 'String'
                  )
                  puts "   OK".bold
                rescue
                  puts "   ERROR".bold.red
                end

              when :update
                print "UPDATE".bold.blue + " " + item.ssm_key
                begin
                  target.ssm.put_parameter(
                    name: item.ssm_key,
                    value: item.local_content[0],
                    type: item.local_content[1] ? 'SecureString' : 'String',
                    overwrite: true
                  )
                  puts "   OK".bold
                rescue
                  puts "   ERROR".bold.red
                end

              when :delete
                print "DELETE".bold.red + " " + item.ssm_key
                begin
                  target.ssm.delete_parameter(name: item.ssm_key)
                  puts "   OK".bold
                rescue
                  puts "   ERROR".bold.red
                end

              else
                if Paramsync.config.verbose?
                  STDERR.puts "paramsync: WARNING: unexpected operation '#{item.op}' for #{item.ssm_key}"
                  next
                end

              end
            end
          end
        end
      end
    end
  end
end
