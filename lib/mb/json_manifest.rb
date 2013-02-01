module MotherBrain
  # @author Jamie Winsor <jamie@vialstudios.com>
  class JSONManifest < Hash
    class << self
      # @param [#to_s] path
      #
      # @raise [ManifestNotFound] if the manifest file is not found
      #
      # @return [JSONManifest]
      def from_file(path)
        path = File.expand_path(path.to_s)
        data = File.read(path)
        obj = new().from_json(data)
        obj.path = path
        obj
      rescue Errno::ENOENT
        raise ManifestNotFound, "No manifest found at: '#{path}'"
      end

      # @param [#to_s] data
      #
      # @return [JSONManifest]
      def from_json(data)
        new.from_json(data)
      end

      # @param [Hash] data
      #
      # @return [JSONManifest]
      def from_hash(data)
        new.from_hash(data)
      end
    end

    # return [String]
    attr_accessor :path

    # @param [Hash] attributes (Hash.new)
    def initialize(attributes = Hash.new)
      unless attributes.nil? || attributes.empty?
        from_hash(attributes)
      end
    end

    # @param [String] json
    # @param [Hash] options
    #   @see MultiJson.decode
    #
    # @raise [InvalidProvisionManifest] if the given string is not valid JSON
    #
    # @return [Provisioner::Manifest]
    def from_json(json, options = {})
      from_hash(MultiJson.decode(json, options))
    rescue MultiJson::DecodeError => e
      raise InvalidJSONManifest, e
    end

    # @param [Hash] hash
    #
    # @return [Provisioner::Manifest]
    def from_hash(hash)
      mass_assign(hash)

      self
    end

    # @param [String] path
    #
    # @raise [MB::InternalError] if the path attribute is nil or an empty string
    #
    # @return [Provisioner::Manifest]
    def save(path = nil)
      self.path = path || self.path

      unless self.path.present?
        raise InternalError, "Cannot save manifest without a destination. Set the 'path' attribute on your object."
      end

      FileUtils.mkdir_p(File.dirname(self.path))
      File.open(self.path, 'w+') do |f|
        f.write(MultiJson.dump(self, pretty: true))
      end

      self
    end

    private

      # Assign the key value pairs of the given hash to self
      #
      # @param [Hash] hash
      def mass_assign(hash)
        hash.each_pair do |key, value|
          self[key] = value
        end

        deep_symbolize_keys!

        each do |key, value|
          if value.is_a?(Array)
            value.each do |object|
              if object.respond_to?(:deep_symbolize_keys!)
                object.deep_symbolize_keys!
              end
            end
          end
        end
      end
  end
end
