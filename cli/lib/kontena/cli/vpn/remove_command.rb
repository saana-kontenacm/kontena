module Kontena::Cli::Vpn
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?
      name = 'vpn'
      vpn = client(token).get("services/#{current_grid}/#{name}") rescue nil
      abort("#{name} service does not exist") if vpn.nil?


      ShellSpinner "removing #{vpn.colorize(:cyan)} service " do
        client(token).delete("services/#{current_grid}/vpn")
      end
    end
  end
end
