begin
  Mongoid::QueryCache.cache {
    json.services @grid_services do |grid_service|
      json.partial! 'app/views/v1/grid_services/grid_service', grid_service: grid_service
    end
  }
ensure
  Mongoid::QueryCache.clear_cache
end
