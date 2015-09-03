module Builderator
  module Util
    class << self
      def to_array(arg)
        arg.is_a?(Array) ? arg : [arg]
      end

      def from_tags(aws_tags)
        {}.tap { |tt| aws_tags.each { |t| tt[t.key.to_s] = t.value } }
      end

      def filter(resources, filters = {})
        resources.select do |_, r|
          filters.reduce(true) do |memo, (k, v)|
            memo && r[:properties].include?(k.to_s) &&
              r[:properties][k.to_s] == v
          end
        end
      end

      def filter!(resources, filters = {})
        resources.select! do |_, r|
          filters.reduce(true) do |memo, (k, v)|
            memo && r[:properties].include?(k.to_s) &&
              r[:properties][k.to_s] == v
          end
        end

        resources
      end

      def region(arg = nil)
        return @region || 'us-east-1' if arg.nil?
        @region = arg
      end

      def ec2
        @ec2 ||= Aws::EC2::Client.new(:region => region)
      end

      def asg
        @asg ||= Aws::AutoScaling::Client.new(:region => region)
      end

      def working_dir(relative = '.')
        File.expand_path(relative, Dir.pwd)
      end
    end
  end
end

require_relative './util/aws_exception'
require_relative './util/limit_exception'
