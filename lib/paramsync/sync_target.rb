# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class SyncTarget
    VALID_CONFIG_KEYS = %w( name type region prefix path exclude chomp delete erb_enabled account )
    attr_accessor :name, :type, :region, :prefix, :path, :exclude, :erb_enabled, :account, :ssm

    REQUIRED_CONFIG_KEYS = %w( prefix region account )
    VALID_TYPES = [ :dir, :file ]
    DEFAULT_TYPE = :dir

    def initialize(config:, account:, base_dir:)
      if not config.is_a? Hash
        raise Paramsync::ConfigFileInvalid.new("Sync target entries must be specified as hashes")
      end

      if (config.keys - Paramsync::SyncTarget::VALID_CONFIG_KEYS) != []
        raise Paramsync::ConfigFileInvalid.new("Only the following keys are valid in a sync target entry: #{Paramsync::SyncTarget::VALID_CONFIG_KEYS.join(", ")}")
      end

      if (Paramsync::SyncTarget::REQUIRED_CONFIG_KEYS - config.keys) != []
        raise Paramsync::ConfigFileInvalid.new("The following keys are required in a sync target entry: #{Paramsync::SyncTarget::REQUIRED_CONFIG_KEYS.join(", ")}")
      end

      @base_dir = base_dir
      self.region = config['region']
      self.prefix = config['prefix']
      self.account = config['account']
      self.path = config['path'] || config['prefix']
      self.name = config['name']
      self.type = (config['type'] || Paramsync::SyncTarget::DEFAULT_TYPE).to_sym
      unless Paramsync::SyncTarget::VALID_TYPES.include?(self.type)
        raise Paramsync::ConfigFileInvalid.new("Sync target '#{self.name || self.path}' has type '#{self.type}'. But only the following types are valid: #{Paramsync::SyncTarget::VALID_TYPES.collect(&:to_s).join(", ")}")
      end

      if self.type == :file and File.directory?(self.base_path)
        raise Paramsync::ConfigFileInvalid.new("Sync target '#{self.name || self.path}' has type 'file', but path '#{self.path}' is a directory.")
      end

      self.exclude = config['exclude'] || []
      if config.has_key?('chomp')
        @do_chomp = config['chomp'] ? true : false
      end
      if config.has_key?('delete')
        @do_delete = config['delete'] ? true : false
      else
        @do_delete = false
      end

      self.ssm = Aws::SSM::Client.new(
        region: region,
        credentials: Aws::AssumeRoleCredentials.new(
          client: Aws::STS::Client.new(region: region),
          role_arn: account,
          role_session_name: "paramsync"
        ),
      )
      self.erb_enabled = config['erb_enabled']
    end

    def erb_enabled?
      @erb_enabled
    end

    def chomp?
      @do_chomp
    end

    def delete?
      @do_delete
    end

    def description(mode = :push)
      if mode == :pull
        "#{self.name.nil? ? '' : self.name.bold + "\n"}#{'ssm'.cyan}:#{self.region.green}:#{self.prefix} => #{'local'.blue}:#{self.path}"
      else
        "#{self.name.nil? ? '' : self.name.bold + "\n"}#{'local'.blue}:#{self.path} => #{'ssm'.cyan}:#{self.region.green}:#{self.prefix}"
      end
    end

    def clear_cache
      @base_path = nil
      @local_files = nil
      @local_items = nil
      @remote_items = nil
    end

    def base_path
      @base_path ||= File.join(@base_dir, self.path)
    end

    def local_files
      # see https://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
      @local_files ||= Dir["#{self.base_path}/**{,/*/**}/*"].select { |f| File.file?(f) }
    end

    def local_items
      return @local_items if not @local_items.nil?
      @local_items = {}

      case self.type
      when :dir
        self.local_files.each do |local_file|
          @local_items[local_file.sub(%r{^#{self.base_path}/?}, '')] =
            load_local_file(local_file)
        end

      when :file
        if File.exist?(self.base_path)
          @local_items = local_items_from_file
        end
      end
      @local_items.transform_values! do |val|
        is_kms = val.bytes[0] == 0x01
        if is_kms
          val = Paramsync.config.kms_client.decrypt(
            ciphertext_blob: val
          ).plaintext
        end
        [val, is_kms]
      end
      @local_items
    end

    def local_items_from_file
      if erb_enabled?
        loaded_file = YAML.load(ERB.new(File.read(self.base_path)).result)
      else
        loaded_file = YAML.load_file(self.base_path)
      end

      flatten_hash(nil, loaded_file)
    end

    def load_local_file(local_file)
      file = File.read(local_file)

      if self.chomp?
        encoded_file = file.chomp.force_encoding(Encoding::ASCII_8BIT)
      else
        encoded_file = file.force_encoding(Encoding::ASCII_8BIT)
      end

      return ERB.new(encoded_file).result if erb_enabled?
      encoded_file
    end

    def remote_items
      return @remote_items if not @remote_items.nil?
      @remote_items = {}

      resp = self.ssm.get_parameters_by_path(
        path: self.prefix,
        recursive: true,
        with_decryption: true
      )

      return @remote_items if resp.values.nil?
      resp.flat_map(&:parameters).each do |param|
        @remote_items[param.name.gsub(self.prefix, '')] = [(param.value.nil? ? '' : param.value), param.type == 'SecureString']
      end

      @remote_items
    end

    def diff(mode)
      Paramsync::Diff.new(target: self, local: self.local_items, remote: self.remote_items, mode: mode)
    end

    private def flatten_hash(prefix, hash)
      new_hash = {}

      hash.each do |k, v|
        if k == '_' && !prefix.nil?
          new_key = prefix
        else
          new_key = [prefix, k].compact.join('.').gsub('/.', '/')
        end

        case v
        when Hash
          new_hash.merge!(flatten_hash(new_key, v))
        else
          new_hash[new_key] = v.to_s
        end
      end

      new_hash
    end
  end
end
