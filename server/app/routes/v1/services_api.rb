module V1
  class ServicesApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers
    include Auditor

    plugin :multi_route
    plugin :streaming

    Dir[File.join(__dir__, '/services/*.rb')].each{|f| require f}

    route do |r|

      validate_access_token
      require_current_user

      # @param [String] grid_name
      # @param [String] stack_name
      # @param [String] service_name
      # @return [GridService]
      def load_grid_service(grid_name, stack_name, service_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Not found'}) if !grid
        stack = grid.stacks.find_by(name: stack_name)
        halt_request(404, {error: 'Not found'}) if !stack
        grid_service = stack.grid_services.find_by(name: service_name)
        halt_request(404, {error: 'Not found'}) if !grid_service

        unless current_user.grid_ids.include?(grid_service.grid_id)
          halt_request(403, {error: 'Access denied'})
        end

        grid_service
      end

      def build_scope(service, r)
        scope = @grid_service.container_logs

        scope = scope.where(name: r['container']) unless r['container'].nil?
        scope = scope.where(:$text => {:$search => r['search']}) unless r['search'].nil?
        if !r['since'].nil? && r['from'].nil?
          since = DateTime.parse(r['since']) rescue nil
          scope = scope.where(:created_at.gt => since)
        end
        scope = scope.where(:id.gt => r['from'] ) unless r['from'].nil?
        scope = scope.order(:_id => -1)
        scope
      end

      # /v1/services/:grid_name/:stack_name/:service_name
      r.on ':grid_name/:stack_name/:service_name' do |grid_name, stack_name, service_name|
        @grid_service = load_grid_service(grid_name, stack_name, service_name)

        # /v1/services/:grid_name/:stack_name/:service_name/containers
        r.on 'containers' do
          r.route 'service_containers'
        end

        # /v1/services/:grid_name/:stack_name/:service_name/stats
        r.on 'stats' do
          r.route 'service_stats'
        end

        # /v1/services/:grid_name/:stack_name/:service_name/envs
        r.on 'envs' do
          r.route 'service_envs'
        end

        # GET /v1/services/:grid_name/:stack_name/:service_name
        r.get do
          r.is do
            render('grid_services/show')
          end

          r.on 'container_logs' do
            follow = r['follow']
            from = r['from']
            limit = (r['limit'] || 100).to_i

            scope = build_scope(@grid_service, r)

            if follow
              first_run = true
              stream(loop: true) do |out|
                scope = scope.where(:id.gt => from ) unless from.nil?
                if first_run
                  logs = scope.limit(limit).to_a.reverse
                else
                  logs = scope.to_a.reverse
                end

                logs.each do |log|
                  out << render('container_logs/_container_log', {locals: {log: log}})
                end
                first_run = false

                sleep 0.5 if logs.size == 0
                from = logs.last.id if logs.last
              end
            else
              @logs = scope.order(:_id => -1).limit(limit).to_a.reverse
              render('container_logs/index')
            end
          end
        end

        # POST /v1/services/:grid_name/:stack_name/:service_name
        r.post do
          # POST /v1/services/:grid_name/:stack_name/:service_name/deploy
          r.on('deploy') do
            data = parse_json_body rescue {}
            data[:current_user] = current_user
            data[:grid_service] = @grid_service
            outcome = GridServices::Deploy.run(data)
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'deploy', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          # POST /v1/services/:grid_name/:stack_name/:service_name/scale
          r.on('scale') do
            data = parse_json_body
            outcome = GridServices::Scale.run(
                current_user: current_user,
                grid_service: @grid_service,
                instances: data['instances']
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'scale', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          # POST /v1/services/:grid_name/:stack_name/:service_name/restart
          r.on('restart') do
            outcome = GridServices::Restart.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'restart', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          # POST /v1/services/:grid_name/:stack_name/:service_name/stop
          r.on('stop') do
            outcome = GridServices::Stop.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'stop', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          # POST /v1/services/:grid_name/:stack_name/:service_name/start
          r.on('start') do
            outcome = GridServices::Start.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'start', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          # POST /v1/services/:grid_name/:stack_name/:service_name/exec
          r.on 'exec' do
            data = parse_json_body
            container = @grid_service.containers.where(name: "#{@grid_service.name}-#{data['instance']}")
            halt_request(404) unless container
            Docker::ContainerExecutor.new(container).exec_in_container(data['cmd'])
          end
        end

        # PUT /v1/services/:grid_name/:stack_name/:service_name
        r.put do
          data = parse_json_body
          data[:current_user] = current_user
          data[:grid_service] = @grid_service
          outcome = GridServices::Update.run(data)
          if outcome.success?
            @grid_service = outcome.result
            audit_event(r, @grid_service.grid, @grid_service, 'update', @grid_service)
            render('grid_services/show')
          else
            response.status = 422
            outcome.errors.message
          end
        end

        # DELETE /v1/services/:grid_name/:stack_name/:service_name
        r.delete do
          r.is do
            outcome = GridServices::Delete.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'delete', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end
        end
      end
    end
  end
end
