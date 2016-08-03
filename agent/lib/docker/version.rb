module Docker
  remove_const :API_VERSION if defined? Docker::API_VERSION
  API_VERSION = '1.21'.freeze
end
