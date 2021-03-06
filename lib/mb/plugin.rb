module MotherBrain
  class Plugin
    class << self
      # Create a new plugin instance from the given content
      #
      # @param [MB::CookbookMetadata] metadata
      #
      # @raise [PluginLoadError]
      #
      # @yieldreturn [MotherBrain::Plugin]
      def load(metadata, &block)
        new(metadata, &block).validate!
      rescue PluginSyntaxError => ex
        ErrorHandler.wrap(ex)
      end

      # Load the contents of a directory into an instance of MB::Plugin
      #
      # @param [#to_s] path
      #   a path to a directory containing a motherbrain plugin file and cookbook
      #   metadata file
      #
      # @raise [PluginLoadError]
      #
      # @return [MotherBrain::Plugin]
      def from_path(path)
        unless Dir.has_mb_plugin?(path)
          raise PluginLoadError, "Expected a motherbrain and metadata file at: #{path}"
        end

        plugin_filename = File.join(path, PLUGIN_FILENAME)
        plugin_contents = File.read(plugin_filename)
        metadata        = CookbookMetadata.from_path(path)

        load(metadata) { eval(plugin_contents, binding, plugin_filename, 1) }
      rescue PluginSyntaxError => ex
        raise PluginSyntaxError, ErrorHandler.new(ex, file_path: plugin_filename).message
      end

      def key_for(name, version)
        "#{name}-#{version}".to_sym
      end
    end

    NODE_GROUP_ID_REGX = /^(.+)::(.+)$/.freeze
    PLUGIN_FILENAME    = 'motherbrain.rb'.freeze

    extend Forwardable
    include Comparable
    include VariaModel

    attribute :bootstrap_routine,
      type: MB::Bootstrap::Routine

    # @return [MB::CookbookMetadata]
    attr_reader :metadata
    # @return [Set<MB::Component>]
    attr_reader :components
    # @return [Set<MB::Command>]
    attr_reader :commands

    def_delegator :metadata, :name
    def_delegator :metadata, :maintainer
    def_delegator :metadata, :maintainer_email
    def_delegator :metadata, :license
    def_delegator :metadata, :description
    def_delegator :metadata, :long_description
    def_delegator :metadata, :version

    # @param [MB::CookbookMetadata] metadata
    def initialize(metadata, &block)
      @metadata     = metadata
      @components   = Set.new
      @commands     = Set.new

      if block_given?
        dsl_eval(&block)
      end
    end

    # @return [Symbol]
    def id
      self.class.key_for(self.name, self.version)
    end

    # @param [#to_s] name
    #
    # @return [MB::Component, nil]
    def component(name)
      components.find { |component| component.name == name.to_s }
    end

    # @param [#to_s] name
    #
    # @raise [ComponentNotFound] if a component of the given name is not a part of this plugin
    #
    # @return [MB::Component]
    def component!(name)
      component = component(name)

      if component.nil?
        raise ComponentNotFound.new(name, self)
      end

      component
    end

    # @param [#to_s] name
    #
    # @return [Boolean]
    def has_component?(name)
      component(name).present?
    end

    # Return a command from the plugins list of commands.
    #
    # @param [#to_s] name
    #   name of the command to find and return
    #
    # @return [MB::Command, nil]
    def command(name)
      commands.find { |command| command.name == name.to_s }
    end

    # Return a command from the plugin's list of commands. If a command is not found an exception will be rasied.
    #
    # @param [#to_s] name
    #   name of the command to find and return
    #
    # @raise [CommandNotFound] if a command matching the given name is not found on this plugin
    #
    # @return [MB::Command]
    def command!(name)
      found = command(name)

      if found.nil?
        raise CommandNotFound.new(name, self)
      end

      found
    end

    # Finds the nodes for the given environment for each {Component} of the plugin groups them
    # by Component#name and Group#name into a Hash where the keys are Component#name and
    # values are a hash where the keys are Group#name and the values are a Hash representing
    # a node from Chef.
    #
    # @param [#to_s] environment
    #
    # @raise [MB::EnvironmentNotFound] if the target environment does not exist
    # @raise [MB::ChefConnectionError] if there was an error communicating to the Chef Server
    #
    # @example
    #
    #   {
    #     "activemq" => {
    #       database_masters" => [
    #         {
    #           "name" => "db-master1",
    #           ...
    #         }
    #       ],
    #       "database_slaves" => [
    #         {
    #           "name" => "db-slave1",
    #           ...
    #         },
    #         {
    #           "name" => "db-slave2",
    #           ...
    #         }
    #       ]
    #     }
    #   }
    #
    # @return [Hash]
    def nodes(environment)
      unless Application.ridley.environment.find(environment)
        raise EnvironmentNotFound.new(environment)
      end

      {}.tap do |nodes|
        self.components.each do |component|
          nodes[component.name] = component.nodes(environment)
        end
      end
    end

    # @param [MB::Component] component
    def add_component(component)
      self.components.add(component)
    end

    # @param [MB::Command] command
    def add_command(command)
      self.commands.add(command)
    end

    # Completely validate a loaded plugin and raise an exception of errors
    #
    # @return [self]
    def validate!
      errors = validate

      if errors.any?
        ErrorHandler.wrap PluginSyntaxError,
          backtrace: [],
          plugin_name: try(:name),
          plugin_version: try(:version),
          text: messages_from_errors(errors)
      end

      self
    end

    # Creates an error message from an error hash, where the keys are attributes
    # and the values are an array of error messages.
    #
    # @param [Hash] errors
    #
    # @return [String]
    def messages_from_errors(errors)
      buffer = []

      errors.each do |attribute, messages|
        buffer |= messages
      end

      buffer.join "\n"
    end

    def <=>(other)
      unless other.is_a?(self.class)
        return 0
      end

      if self.name == other.name
        self.version <=> other.version
      else
        self.name <=> other.name
      end
    end

    def eql?(other)
      other.is_a?(self.class) && self == other
    end

    def to_s
      "#{self.name} (#{self.version})"
    end

    def to_hash
      {
        name: name,
        version: version,
        maintainer: maintainer,
        maintainer_email: maintainer_email,
        description: description,
        long_description: long_description
      }
    end

    # @param [Hash] options
    #   a set of options to pass to MultiJson.encode
    #
    # @return [String]
    def to_json(options = {})
      MultiJson.encode(self.to_hash, options)
    end
    alias_method :as_json, :to_json

    private

      def dsl_eval(&block)
        CleanRoom.new(self).instance_eval(&block)
      end

    # @api private
    class CleanRoom < CleanRoomBase
      # @param [#to_s] name
      def command(name, &block)
        real_model.add_command Command.new(name, real_model, &block)
      end

      # @param [#to_s] name
      def component(name, &block)
        real_model.add_component Component.new(name, real_model, &block)
      end

      def stack_order(&block)
        real_model.bootstrap_routine = Bootstrap::Routine.new(real_model, &block)
      end

      def cluster_bootstrap(&block)
        MB.log.warn "#{real_model}: cluster_bootstrap is now stack_order, and will be removed in motherbrain 1.0"
        stack_order(&block)
      end
    end
  end
end
