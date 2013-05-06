require "fog"

module Bosh::Inception
  class InceptionServer

    DEFAULT_SIZE = "m1.small"
    DEFAULT_SECURITY_GROUPS = ["ssh"]

    # @provider_client [Bosh::Providers::FogProvider] - interact with IaaS
    # @attributes [Settingslogic]
    #
    # Required @attributes:
    #   {
    #     "ip_address" => "54.214.15.178",
    #     "key_pair" => {
    #       "name" => "inception",
    #       "private_key" => "private_key",
    #       "public_key" => "public_key"
    #     }
    #   }
    #
    # Including optional @attributes and default values:
    #   {
    #     "ip_address" => "54.214.15.178",
    #     "security_groups" => ["ssh"],
    #     "size" => "m1.small",
    #     "key_pair" => {
    #       "name" => "inception",
    #       "private_key" => "private_key",
    #       "public_key" => "public_key"
    #     }
    #     "local_private_key_path" => "~/.bosh_inception/ssh/inception"
    #   }
    def initialize(provider_client, attributes, ssh_dir)
      @provider_client = provider_client
      @ssh_dir = ssh_dir
      @attributes = attributes.is_a?(Hash) ? Settingslogic.new(attributes) : attributes
      raise "@attributes must be Settingslogic (or Hash)" unless @attributes.is_a?(Settingslogic)
    end

    # Create the underlying server, with key pair & security groups, unless it is already created
    def create
      validate_attributes_for_bootstrap
      ensure_local_private_key
      ensure_required_security_groups
      create_missing_default_security_groups
      @attributes.create_accessors!
      @provider_client.bootstrap(fog_attributes)
    end

    def security_groups
      @attributes.security_groups
    end

    def key_name
      @attributes.key_pair.name
    end

    def private_key_path
      @attributes["local_private_key_path"] ||= File.join(@ssh_dir, key_name)
    end

    def size
      @attributes["size"] ||= DEFAULT_SIZE
    end

    def ip_address
      @attributes.ip_address
    end

    protected
    def fog_attributes
      {
        :groups => security_groups,
        :key_name => key_name,
        :private_key_path => private_key_path,
        :flavor_id => size,
        :public_ip_address => ip_address,
        :bits => 64,
        :username => "ubuntu",
      }
    end

    def validate_attributes_for_bootstrap
      missing_attributes = []
      missing_attributes << "ip_address" unless @attributes["ip_address"]
      missing_attributes << "key_pair" unless @attributes["key_pair"]
      missing_attributes << "key_pair.private_key" if @attributes["key_pair"]["private_key"].empty?
      missing_attributes << "key_pair.public_key" if @attributes["key_pair"]["public_key"].empty?
      if missing_attributes.size > 0
        raise "Missing InceptionServer attributes: #{missing_attributes.join(', ')}"
      end
    end

    # store private key into +private_key_path+ file
    def ensure_local_private_key
      
    end

    # ssh group must be first (bootstrap method looks for port 22 in first group)
    def ensure_required_security_groups
      if @attributes["security_groups"] && @attributes["security_groups"].is_a?(Array)
        unless @attributes["security_groups"].include?("ssh")
          @attributes["security_groups"] = ["ssh", *@attributes["security_groups"]]
        end
      else
        @attributes["security_groups"] = ["ssh"]
      end
    end

    def create_missing_default_security_groups
      # provider method only creates group if missing
      @provider_client.create_security_group("ssh", "ssh", {ssh: 22})
    end

  end
end