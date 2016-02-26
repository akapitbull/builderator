require 'aws-sdk'
require 'thor'

require_relative '../control/data'
require_relative '../interface/packer'
require_relative '../patch/thor-actions'

module Builderator
  module Tasks
    ##
    # Wrap Packer commands
    ##
    class Packer < Thor
      include Thor::Actions

      def self.exit_on_failure?
        true
      end

      class_option :debug, :type => :boolean

      desc 'configure [PROFILE=default]', 'Generate a packer configuration'
      def configure(profile = :default)
        Config.profile.use(profile)

        invoke Tasks::Version, :current, [], options
        puts Interface.packer.render if options['debug']
      end

      desc 'build [PROFILE=default *ARGS]', 'Run a build with the installed version of packer'
      def build(profile = :default, *args)
        invoke :configure, [profile], options
        run_with_input "#{Interface.packer.command} build - #{ args.join('') }", Interface.packer.render
      end

      desc 'copy PROFILE *REGIONS', 'Copy AMIs generated by packer to REGIONS'
      def copy(profile, *regions)
        invoke :configure, [profile], options

        regions.each do |region|
          images.each do |image_name, image|
            say_status :copy, "AMI #{image_name} (#{image.image_id}) from #{Config.aws.region} to #{region}"

            client(region).copy_image(:source_region => Config.aws.region,
                                      :source_image_id => image.image_id,
                                      :name => image_name,
                                      :description => image.description)
          end
        end

        invoke :tag, [profile, *regions], options
      end

      desc 'tag PROFILE *REGIONS', 'Tag AMIs in REGIONS'
      method_option :accounts, :type => :array, :default => []
      def tag(profile, *regions)
        invoke :configure, [profile], options

        images.each do |image_name, image|
          regions.each do |region|
            regional_image = client(region).describe_images(:filters => [{
                                                              :name => 'name',
                                                              :values => [image_name]
                                                            }]).images.first

            say_status :tag, "AMI #{image_name} (#{regional_image.image_id}) in #{region}"
            client(region).create_tags(:resources => [regional_image.image_id], :tags => image.tags)
          end
        end
      end

      private

      ## Find details for generated images
      def images
        @images ||= Config.profile.current.packer.build.each_with_object({}) do |(_, build), memo|
          memo[build.ami_name] = Control::Data.lookup(:image, :name => build.ami_name).first
        end
      end

      def _region_clients
        @_region_clients = {}
      end

      def client(region)
        _region_clients[region] ||= Aws::EC2::Client.new(:region => region)
      end
    end
  end
end
