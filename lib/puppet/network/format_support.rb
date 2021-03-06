require 'puppet/network/format_handler'

# Provides network serialization support when included
module Puppet::Network::FormatSupport
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def convert_from(format, data)
      get_format(format).intern(self, data)
    rescue => err
      raise Puppet::Network::FormatHandler::FormatError, "Could not intern from #{format}: #{err}", err.backtrace
    end

    def convert_from_multiple(format, data)
      get_format(format).intern_multiple(self, data)
    rescue => err
      raise Puppet::Network::FormatHandler::FormatError, "Could not intern_multiple from #{format}: #{err}", err.backtrace
    end

    def render_multiple(format, instances)
      get_format(format).render_multiple(instances)
    rescue => err
      raise Puppet::Network::FormatHandler::FormatError, "Could not render_multiple to #{format}: #{err}", err.backtrace
    end

    def default_format
      supported_formats[0]
    end

    def support_format?(name)
      Puppet::Network::FormatHandler.format(name).supported?(self)
    end

    def supported_formats
      result = format_handler.formats.collect { |f| format_handler.format(f) }.find_all { |f| f.supported?(self) }.collect { |f| f.name }.sort do |a, b|
        # It's an inverse sort -- higher weight formats go first.
        format_handler.format(b).weight <=> format_handler.format(a).weight
      end

      result = put_preferred_format_first(result)

      Puppet.debug "#{friendly_name} supports formats: #{result.map{ |f| f.to_s }.sort.join(' ')}; using #{result.first}"

      result
    end

    # @api private
    def get_format(format_name)
      format_handler.format_for(format_name)
    end

    private

    def format_handler
      Puppet::Network::FormatHandler
    end

    def friendly_name
      if self.respond_to? :indirection
        indirection.name
      else
        self
      end
    end

    def put_preferred_format_first(list)
      preferred_format = Puppet.settings[:preferred_serialization_format].to_sym
      if list.include?(preferred_format)
        list.delete(preferred_format)
        list.unshift(preferred_format)
      else
        Puppet.debug "Value of 'preferred_serialization_format' (#{preferred_format}) is invalid for #{friendly_name}, using default (#{list.first})"
      end
      list
    end
  end

  def render(format = nil)
    format ||= self.class.default_format

    self.class.get_format(format).render(self)
  rescue => err
    raise Puppet::Network::FormatHandler::FormatError, "Could not render to #{format}: #{err}", err.backtrace
  end

  def mime(format = nil)
    format ||= self.class.default_format

    self.class.get_format(format).mime
  rescue => err
    raise Puppet::Network::FormatHandler::FormatError, "Could not mime to #{format}: #{err}", err.backtrace
  end

  def support_format?(name)
    self.class.support_format?(name)
  end
end

