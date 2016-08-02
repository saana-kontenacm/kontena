V1::ServicesApi.route('service_container_logs') do |r|

  # GET /v1/services/:grid_name/:service_name/containers
  r.get do
    r.is do
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
end
