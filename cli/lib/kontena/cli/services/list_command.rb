require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    option '--stack', 'STACK', 'Stack name'

    def execute
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services?stack=#{stack}")
      services = grids['services'].sort_by{|s| s['updated_at'] }.reverse
      show_services(services)
    end
  end
end
