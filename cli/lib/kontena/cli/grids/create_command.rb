require_relative 'common'

module Kontena::Cli::Grids
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"
    option "--initial-size", "INITIAL_SIZE", "Initial grid size (number of nodes)", default: 1

    def execute
      require_api_url

      token = require_token
      payload = {
        name: name
      }
      payload[:initial_size] = initial_size if initial_size
      grid = nil
      if initial_size == 1
        STDERR.puts "WARNING: --initial-size=1 is only recommended for test/dev usage".colorize(:yellow)
      end
      ShellSpinner "creating #{name.colorize(:cyan)} grid " do
        grid = client(token).post('grids', payload)
      end
      if grid
        ShellSpinner "switching scope to #{name.colorize(:cyan)} grid " do
          self.current_grid = grid
        end
      end
    end
  end
end
