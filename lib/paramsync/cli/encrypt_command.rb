# This software is public domain. No rights are reserved. See LICENSE for more information.

class Paramsync
  class CLI
    class EncryptCommand
      class << self
        def run(args)
          Paramsync::CLI.configure
          STDOUT.sync = true

          ciphertext = Paramsync.config.kms_client.encrypt(
              key_id: Paramsync.config.kms_key,
              plaintext: args[1]
            ).ciphertext_blob

          hash = { args[0] => ciphertext }
          puts YAML.dump(hash).gsub("---\n", '')
        end
      end
    end
  end
end
