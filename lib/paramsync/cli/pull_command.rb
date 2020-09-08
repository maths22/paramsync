# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class CLI
    class PullCommand
      class << self
        def run(args)
          Paramsync::CLI.configure
          STDOUT.sync = true

          Paramsync.config.sync_targets.each do |target|
            diff = target.diff(:pull)

            diff.print_report

            if not diff.any_changes?
              puts
              puts "Everything is in sync. No changes need to be made to this sync target."
              next
            end

            puts
            puts "Do you want to pull these changes?"
            print "  Enter '" + "yes".bold + "' to continue: "
            answer = args.include?('--yes') ? 'yes' : gets.chomp

            if answer.downcase != "yes"
              puts
              puts "Pull cancelled. No changes will be made to this sync target."
              next
            end

            puts
            case target.type
            when :dir then self.pull_dir(diff)
            when :file then self.pull_file(diff)
            end
          end
        end

        def pull_dir(diff)
          diff.items_to_change.each do |item|
            case item.op
            when :create
              print "CREATE".bold.green + " " + item.display_filename
              begin
                FileUtils.mkdir_p(File.dirname(item.filename))
                # attempt to write atomically-ish
                tmpfile = item.filename + ".paramsync-tmp"
                File.open(tmpfile, "w") do |f|
                  f.write(item.remote_content)
                end
                FileUtils.move(tmpfile, item.filename)
                puts "   OK".bold
              rescue => e
                puts "   ERROR".bold.red
                puts "  #{e}"
              end

            when :update
              print "UPDATE".bold.blue + " " + item.display_filename
              begin
                # attempt to write atomically-ish
                tmpfile = item.filename + ".paramsync-tmp"
                File.open(tmpfile, "w") do |f|
                  f.write(item.remote_content)
                end
                FileUtils.move(tmpfile, item.filename)
                puts "   OK".bold
              rescue => e
                puts "   ERROR".bold.red
                puts "  #{e}"
              end

            when :delete
              print "DELETE".bold.red + " " + item.display_filename
              begin
                File.unlink(item.filename)
                puts "   OK".bold
              rescue => e
                puts "   ERROR".bold.red
                puts "  #{e}"
              end

            else
              if Paramsync.config.verbose?
                STDERR.puts "paramsync: WARNING: unexpected operation '#{item.op}' for #{item.display_filename}"
                next
              end

            end
          end
        end

        def pull_file(diff)
          # build and write the file
          filename_list = diff.items_to_change.collect(&:filename).uniq
          if filename_list.length != 1
            raise Paramsync::InternalError.new("Multiple filenames found for a 'file' type sync target. Something has gone wrong.")
          end
          filename = filename_list.first
          display_filename = filename.trim_path

          if File.exist?(filename)
            print "UPDATE".bold.blue + " " + display_filename
          else
            print "CREATE".bold.green + " " + display_filename
          end

          begin
            FileUtils.mkdir_p(File.dirname(filename))
            # attempt to write atomically-ish
            tmpfile = filename + ".paramsync-tmp"
            File.open(tmpfile, "w") do |f|
              f.write(diff.final_items.to_yaml)
            end
            FileUtils.move(tmpfile, filename)
            puts "   OK".bold
          rescue => e
            puts "   ERROR".bold.red
            puts "  #{e}"
          end
        end

      end
    end
  end
end
