module Kontena::Cli::Vpn
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?

      vpn = client(token).get("stacks/#{current_grid}/vpn") rescue nil
      abort("VPN stack does not exist") if vpn.nil?

      client(token).delete("stacks/#{current_grid}/vpn")
    end
  end
end
