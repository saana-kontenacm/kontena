require_relative 'common'

module Kontena::Cli::Apps
  class StartCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services

    def execute
      require_config_file(filename)

      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.size > 0
        start_services(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end

    end

    def start_services(services)
      services.each do |service_name, opts|
        if service_exists?(service_name)
          ShellSpinner "starting #{service_name.colorize(:cyan)} " do
            start_service(token, prefixed_name(service_name))
          end
        else
          STDERR.puts "WARNING: no such service: #{service_name}".colorize(:yellow)
        end
      end
    end
  end
end
