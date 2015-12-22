require_relative '../config'
require_relative '../interface'
require_relative '../util'

module Builderator
  # :nodoc:
  class Interface
    class << self
      def packer
        @packer ||= Packer.new
      end
    end

    ##
    # Generate packer.json
    ##
    class Packer < Interface
      attr_reader :packerfile

      def initialize(*_)
        super

        @packerfile ||= {
          :builders => [],
          :provisioners => []
        }.tap do |json|
          Config.profile.current.packer.build.each do |_, build|
            json[:builders] << build.to_hash.tap do |b|
              b[:tags] = Config.profile.current.tags
            end
          end

          ## Initialize the staging directory
          json[:provisioners] << {
            :type => 'shell',
            :inline => "sudo mkdir -p #{Config.chef.staging_directory}/cache && "\
                       "sudo chown $(whoami) -R #{Config.chef.staging_directory}"
          }
        end

        _artifact_provisioners
        _chef_provisioner
      end

      def render
        JSON.pretty_generate(packerfile)
      end

      private

      ## Upload artifacts to the build container
      def _artifact_provisioners
        Config.profile.current.artifact.each do |_, artifact|
          packerfile[:provisioners] << {
            :type => 'file',
            :source => artifact.path,
            :destination => artifact.destination
          }
        end
      end

      def _chef_provisioner
        packerfile[:provisioners] << {
          :type => 'chef-solo',
          :run_list => Config.profile.current.chef.run_list,
          :cookbook_paths => Config.local.cookbook_path,
          :data_bags_path => Config.local.data_bag_path,
          :environments_path => Config.local.environment_path,
          :chef_environment => Config.profile.current.chef.environment,
          :json => Config.profile.current.chef.node_attrs,
          :staging_directory => Config.chef.staging_directory
        }
      end
    end
  end
end
