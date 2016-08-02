require_relative 'common'

module GridServices
  class Create < Mutations::Command
    include Common

    common_validations

    required do
      model :current_user, class: User
      model :grid, class: Grid
      string :image
      string :name, matches: /^(?!-)(\w|-)+$/ # do not allow "-" as a first character
      boolean :stateful
    end

    optional do
      model :stack, class: Stack
    end

    def validate
      if self.stateful && self.volumes_from && self.volumes_from.size > 0
        add_error(:volumes_from, :invalid, 'Cannot combine stateful & volumes_from')
      end
      if self.strategy && !self.strategies[self.strategy]
        add_error(:strategy, :invalid_strategy, 'Strategy not supported')
      end
      if self.health_check && self.health_check[:interval] < self.health_check[:timeout]
        add_error(:health_check, :invalid, 'Interval has to be bigger than timeout')
      end
    end

    def execute
      attributes = self.inputs.clone
      attributes.delete(:current_user)
      attributes[:image_name] = attributes.delete(:image)

      attributes.delete(:links)
      if self.links
        attributes[:grid_service_links] = build_grid_service_links(self.grid, self.links)
      end

      attributes.delete(:hooks)
      if self.hooks
        attributes[:hooks] = self.build_grid_service_hooks([])
      end

      attributes.delete(:secrets)
      if self.secrets
        attributes[:secrets] = self.build_grid_service_secrets([])
      end

      grid_service = GridService.new(attributes)
      unless grid_service.save
        grid_service.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
      end

      grid_service
    end

    def strategies
      GridServiceScheduler::STRATEGIES
    end
  end
end
