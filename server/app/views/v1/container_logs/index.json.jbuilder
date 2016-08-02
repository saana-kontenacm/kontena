begin
  Mongoid::QueryCache.cache {
    json.logs @logs do |log|
      json.partial! 'app/views/v1/container_logs/container_log', log: log
    end
  }
ensure
  Mongoid::QueryCache.clear_cache
end
