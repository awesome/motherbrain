module MotherBrain
  module Provisioner
    # @author Jamie Winsor <jamie@vialstudios.com>
    #
    # Manifest for creating a set of nodes of a given instance type for a set of node groups
    #
    # @example valid manifest structure
    #   {
    #     "m1.large": {
    #       "activemq::master": 4,
    #       "activemq::slave": 2
    #     }
    #   }
    #
    class Manifest < MotherBrain::Manifest
      class << self
        # Validate the given parameter contains a Hash or Manifest with a valid structure
        #
        # @param [Provisioner::Manifest] manifest
        # @param [MotherBrain::Plugin] plugin
        #
        # @raise [InvalidProvisionManifest] if the given manifest is not well formed
        def validate!(manifest, plugin)
          unless manifest.is_a?(Hash)
            raise InvalidProvisionManifest,
              "The provisioner manifest needs to be a hash, but you provided a(n) #{manifest.class}"
          end

          nodes = manifest[:nodes]

          unless nodes
            raise InvalidProvisionManifest,
              "The provisioner manifest needs to have a key 'nodes' containing an array"
          end

          unless nodes.is_a?(Array)
            raise InvalidProvisionManifest,
              "The provisioner manifest needs to have a key 'nodes' containing an array, but it was a(n) #{nodes.class}"
          end

          nodes.each do |node|
            unless node.is_a?(Hash)
              raise InvalidProvisionManifest,
                "The provisioner manifest needs to have an array of hashes at 'nodes', but there was a #{node.class}: #{node.inspect}"
            end

            type = node[:type]
            count = node[:count]
            components = node[:components]

            unless type.match(/\w+\.\w+/)
              raise InvalidProvisionManifest,
                "Provision manifest contained an entry not in the proper format: '#{type}'. Expected: 'a1.size'"
            end

            if count
              unless count.is_a?(Fixnum) && count >= 0
                raise InvalidProvisionManifest,
                  "Provision manifest contained an invalid value for count: '#{count}'. Expected an integer greater than 0."
              end
            end

            unless components.is_a?(Array)
              raise InvalidProvisionManifest,
                "The provisioner manifest contains a node group without an array of components: #{node.inspect}"
            end

            components.each do |component_string|
              match = component_string.match(Plugin::NODE_GROUP_ID_REGX)

              unless match
                raise InvalidProvisionManifest,
                  "Provision manifest contained an entry not in the proper format: '#{name}'. Expected: 'component::group'"
              end

              component = match[1]
              group = match[2]

              unless plugin.has_component?(component)
                raise InvalidProvisionManifest,
                  "Provision manifest describes the component: '#{component}' but '#{plugin.name}' does not have this component"
              end

              unless plugin.component(component).has_group?(group)
                raise InvalidProvisionManifest,
                  "Provision manifest describes the group: '#{group}' in the component '#{component}' but that component does not have this group"
              end
            end
          end
        end
      end

      # @param [Plugin] plugin
      #
      # @raise [InvalidProvisionManifest] if the given manifest is not well formed
      def validate!(plugin)
        self.class.validate!(self, plugin)
      end
    end
  end
end
