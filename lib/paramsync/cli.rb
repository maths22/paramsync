# This software is public domain. No rights are reserved. See LICENSE for more information.

require_relative '../paramsync'
require 'diffy'
require_relative 'cli/check_command'
require_relative 'cli/push_command'
require_relative 'cli/pull_command'
require_relative 'cli/config_command'
require_relative 'cli/targets_command'

class Paramsync
  class CLI
    class << self
      attr_accessor :command, :cli_mode, :config_file, :extra_args, :targets

      def parse_args(args)
        self.print_usage if args.count < 1
        self.command = nil
        self.config_file = nil
        self.extra_args = []
        self.cli_mode = :command

        while arg = args.shift
          case arg
          when "--help"
            self.cli_mode = :help

          when "--config"
            self.config_file = args.shift

          when "--target"
            self.targets = (args.shift||'').split(",")

          when /^-/
            # additional option, maybe for the command
            self.extra_args << arg

          else
            if self.command.nil?
              # if command is not set, this is probably the command
              self.command = arg
            else
              # otherwise, pass it thru to the child command
              self.extra_args << arg
            end
          end
        end
      end

      def print_usage
        STDERR.puts <<USAGE
Usage:
  #{File.basename($0)} <command> [options]

Commands:
  check        Print a summary of changes to be made
  push         Push changes from filesystem to Consul
  pull         Pull changes from Consul to filesystem
  config       Print a summary of the active configuration
  targets      List target names

General options:
  --help           Print help for the given command
  --config <file>  Use the specified config file
  --target <tgt>   Only apply to the specified target name or names (comma-separated)

Options for 'check' command:
  --pull       Perform dry run in pull mode

Options for 'pull' command:
  --yes        Skip confirmation prompt

Options for 'push' command:
  --yes        Skip confirmation prompt

USAGE
        exit 1
      end

      def configure(call_external_apis: true)
        return if Paramsync.configured?

        begin
          Paramsync.configure(path: self.config_file, targets: self.targets, call_external_apis: call_external_apis)

        rescue Paramsync::ConfigFileNotFound
          if self.config_file.nil?
            STDERR.puts "paramsync: ERROR: No configuration file found"
          else
            STDERR.puts "paramsync: ERROR: Configuration file '#{self.config_file}' was not found"
          end
          exit 1

        rescue Paramsync::ConfigFileInvalid => e
          if self.config_file.nil?
            STDERR.puts "paramsync: ERROR: Configuration file is invalid:"
          else
            STDERR.puts "paramsync: ERROR: Configuration file '#{self.config_file}' is invalid:"
          end
          STDERR.puts "  #{e}"
          exit 1

        rescue Paramsync::ConsulTokenRequired => e
          STDERR.puts "paramsync: ERROR: No Consul token could be found: #{e}"
          exit 1

        rescue Paramsync::VaultConfigInvalid => e
          STDERR.puts "paramsync: ERROR: Vault configuration invalid: #{e}"
          exit 1

        end

        if Paramsync.config.sync_targets.count < 1
          if self.targets.nil?
            STDERR.puts "paramsync: WARNING: No sync targets are defined"
          else
            STDERR.puts "paramsync: WARNING: No sync targets were found that matched the specified list"
          end
        end
      end

      def run
        self.parse_args(ARGV)

        case self.cli_mode
        when :help
          # TODO: per-command help
          self.print_usage

        when :command
          case self.command
          when 'check'      then Paramsync::CLI::CheckCommand.run(self.extra_args)
          when 'push'       then Paramsync::CLI::PushCommand.run(self.extra_args)
          when 'pull'       then Paramsync::CLI::PullCommand.run(self.extra_args)
          when 'config'     then Paramsync::CLI::ConfigCommand.run
          when 'targets'    then Paramsync::CLI::TargetsCommand.run
          when nil          then self.print_usage

          else
            STDERR.puts "paramsync: ERROR: unknown command '#{self.command}'"
            STDERR.puts
            self.print_usage
          end

        else
          STDERR.puts "paramsync: ERROR: unknown CLI mode '#{self.cli_mode}'"
          exit 1

        end
      end
    end
  end
end
