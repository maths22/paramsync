# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'ostruct'

class Paramsync
  class ConfigFileNotFound < RuntimeError; end
  class ConfigFileInvalid < RuntimeError; end

  class Config
    CONFIG_FILENAMES = %w( paramsync.yml )
    VALID_CONFIG_KEYS = %w( sync ssm paramsync )
    VALID_SSM_CONFIG_KEYS = %w( accounts kms )
    VALID_PARAMSYNC_CONFIG_KEYS = %w( verbose chomp delete color )

    attr_accessor :config_file, :base_dir, :sync_targets, :target_allowlist, :ssm_accounts, :kms_client, :kms_key

    class << self
      # discover the nearest config file
      def discover(dir: nil)
        dir ||= Dir.pwd

        CONFIG_FILENAMES.each do |filename|
          full_path = File.join(dir, filename)
          if File.exist?(full_path)
            return full_path
          end
        end

        dir == "/" ? nil : self.discover(dir: File.dirname(dir))
      end
    end

    def initialize(path: nil, targets: nil)
      if path.nil? or File.directory?(path)
        self.config_file = Paramsync::Config.discover(dir: path)
      elsif File.exist?(path)
        self.config_file = path
      else
        raise Paramsync::ConfigFileNotFound.new
      end

      if self.config_file.nil? or not File.exist?(self.config_file) or not File.readable?(self.config_file)
        raise Paramsync::ConfigFileNotFound.new
      end

      self.config_file = File.expand_path(self.config_file)
      self.base_dir = File.dirname(self.config_file)
      self.target_allowlist = targets
      parse!
    end

    def verbose?
      @is_verbose
    end

    def chomp?
      @do_chomp
    end

    def delete?
      @do_delete
    end

    def color?
      @use_color
    end

    def parse!
      raw = {}
      begin
        raw = YAML.load(ERB.new(File.read(self.config_file)).result)
      rescue
        raise Paramsync::ConfigFileInvalid.new("Unable to parse config file as YAML")
      end

      if raw.is_a? FalseClass
        # this generally means an empty config file
        raw = {}
      end

      if not raw.is_a? Hash
        raise Paramsync::ConfigFileInvalid.new("Config file must form a hash")
      end

      raw['ssm'] ||= {}
      if not raw['ssm'].is_a? Hash
        raise Paramsync::ConfigFileInvalid.new("'ssm' must be a hash")
      end

      if (raw['ssm'].keys - VALID_SSM_CONFIG_KEYS) != []
        raise Paramsync::ConfigFileInvalid.new("Only the following keys are valid in the ssm config: #{VALID_SSM_CONFIG_KEYS.join(", ")}")
      end

      self.ssm_accounts = raw['ssm']['accounts']

      raw['paramsync'] ||= {}
      if not raw['paramsync'].is_a? Hash
        raise Paramsync::ConfigFileInvalid.new("'paramsync' must be a hash")
      end

      if (raw['paramsync'].keys - VALID_PARAMSYNC_CONFIG_KEYS) != []
        raise Paramsync::ConfigFileInvalid.new("Only the following keys are valid in the 'paramsync' config block: #{VALID_PARAMSYNC_CONFIG_KEYS.join(", ")}")
      end

      # verbose: default false
      @is_verbose = raw['paramsync']['verbose'] ? true : false
      if ENV['PARAMSYNC_VERBOSE']
        @is_verbose = true
      end

      # chomp: default true
      if raw['paramsync'].has_key?('chomp')
        @do_chomp = raw['paramsync']['chomp'] ? true : false
      else
        @do_chomp = true
      end

      # delete: default false
      @do_delete = raw['paramsync']['delete'] ? true : false

      raw['sync'] ||= []
      if not raw['sync'].is_a? Array
        raise Paramsync::ConfigFileInvalid.new("'sync' must be an array")
      end

      # color: default true
      if raw['paramsync'].has_key?('color')
        @use_color = raw['paramsync']['color'] ? true : false
      else
        @use_color = true
      end

      if raw['ssm'].has_key?('kms')
        self.kms_client = Aws::KMS::Client.new(
          region: raw['ssm']['kms']['region'],
          credentials: Aws::AssumeRoleCredentials.new(
            client: Aws::STS::Client.new(region: raw['ssm']['kms']['region']),
            role_arn: raw['ssm']['kms']['role'],
            role_session_name: "paramsync"
          ),
        )
        self.kms_key = raw['ssm']['kms']['arn']
      end

      self.sync_targets = []
      raw['sync'].each do |target|
        if target.is_a? Hash
          if target['chomp'].nil?
            target['chomp'] = self.chomp?
          end
          if target['delete'].nil?
            target['delete'] = self.delete?
          end
          account = self.ssm_accounts[target['account']]
          if account.nil?
            raise Paramsync::ConfigFileInvalid.new("Account '#{target['account']}' is not defined")
          end
        end

        if not self.target_allowlist.nil?
          # unnamed targets cannot be allowlisted
          next if target['name'].nil?

          # named targets must be on the allowlist
          next if not self.target_allowlist.include?(target['name'])
        end

        self.sync_targets << Paramsync::SyncTarget.new(config: target, account: account['role'], base_dir: self.base_dir)
      end
    end
  end
end
