require_relative '../services/log_helper'

module Kontena::Cli::Grids
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Services::LogHelper

    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    option "--lines", "LINES", "Number of lines to show from the end of the logs"
    option "--since", "SINCE", "Show logs since given timestamp"
    option "--node", "NODE", "Filter by node name", multivalued: true
    option "--service", "SERVICE", "Filter by service name", multivalued: true
    option ["-c", "--container"], "CONTAINER", "Filter by container", multivalued: true

    def execute
      require_api_url
      token = require_token

      query_params = {}
      query_params[:nodes] = node_list.join(",") unless node_list.empty?
      query_params[:services] = service_list.join(",") unless service_list.empty?
      query_params[:containers] = container_list.join(",") unless container_list.empty?
      query_params[:limit] = lines if lines
      query_params[:since] = since if since

      if tail?
        @buffer = ''
        query_params[:follow] = 1
        stream_logs(token, query_params)
      else
        list_logs(token, query_params)
      end
    end

    def list_logs(token, query_params)
      result = client(token).get("grids/#{current_grid}/container_logs", query_params)
      result['logs'].each do |log|
        render_log_line(log)
      end
    end

    # @param [Hash] log
    def render_log_line(log)
      color = color_for_container(log['container_id'])
      prefix = ""
      prefix << "#{log['created_at']} "
      if log['service']
        prefix << "[#{log['node']['name']}:#{log['stack']['name']}/#{log['name']}]"
      else
        prefix << "[#{log['node']['name']}:#{log['name']}]"
      end
      prefix << ":"
      prefix = prefix.colorize(color)
      puts "#{prefix} #{log['data']}"
    end

    def stream_logs(token, query_params)
      begin
        if @last_seen
          query_params[:from] = @last_seen
        end
        result = client(token).get_stream(
          "grids/#{current_grid}/container_logs", log_stream_parser, query_params
        )
      rescue => exc
        if exc.cause.is_a?(EOFError) # Excon wraps the EOFerror into SockerError
          retry
        end
      end
    end
  end
end
