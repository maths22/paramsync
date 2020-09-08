# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'erb'
require 'aws-sdk-kms'
require 'aws-sdk-ssm'
require 'fileutils'
require 'ostruct'
require 'yaml'

require_relative 'paramsync/version'
require_relative 'paramsync/config'
require_relative 'paramsync/diff'
require_relative 'paramsync/sync_target'

class Paramsync
  class InternalError < RuntimeError; end

  class << self
    @@config = nil

    def config
      @@config ||= Paramsync::Config.new
    end

    def configure(path: nil, targets: nil)
      @@config = Paramsync::Config.new(path: path, targets: targets)
    end

    def configured?
      not @@config.nil?
    end
  end
end

# monkeypatch String for display prettiness
class String
  # trim_path replaces the HOME directory on an absolute path with '~'
  def trim_path
    self.sub(%r(^#{ENV['HOME']}), '~')
  end

  def colorize(s,e=0)
    Paramsync.config.color? ? "\e[#{s}m#{self}\e[#{e}m" : self
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def blue
    colorize(34)
  end

  def magenta
    colorize(35)
  end

  def cyan
    colorize(36)
  end

  def gray
    colorize(37)
  end

  def bold
    colorize(1,22)
  end
end
