module Kontena::Cli::Nodes
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      require_current_grid
      token = require_token
      confirm_command(node_id) unless forced?

      ShellSpinner "removing #{node_id.colorize(:cyan)} node from #{current_grid.colorize(:cyan)} grid " do
        client(token).delete("grids/#{current_grid}/nodes/#{node_id}")
      end
    end
  end
end
