require_relative '../logging'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'

module Kontena::NetworkAdapters
  class Weave
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper
    include Kontena::Logging

    WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.5.2'
    WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
    WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

    def initialize(autostart = true)
      @images_exist = false
      @started = false
      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      async.ensure_images if autostart
    end

    # @return [String]
    def weave_image
      "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
    end

    # @return [String]
    def weave_exec_image
      "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
    end

    # @param [Docker::Container] container
    # @return [Boolean]
    def adapter_container?(container)
      adapter_image?(container.config['Image'])
    rescue Docker::Error::NotFoundError
      false
    end

    # @param [String] image
    # @return [Boolean]
    def adapter_image?(image)
      image.to_s.include?(WEAVEEXEC_IMAGE)
    rescue
      false
    end

    def router_image?(image)
      image.to_s == "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
    rescue
      false
    end

    # @return [Boolean]
    def running?
      weave = Docker::Container.get('weave') rescue nil
      return false if weave.nil?
      weave.running?
    end

    # @return [Boolean]
    def images_exist?
      @images_exist == true
    end

    # @return [Boolean]
    def already_started?
      @started == true
    end

    # @param [Hash] opts
    def modify_create_opts(opts)
      modify_host_config(opts)

      opts
    end

    # @param [Hash] opts
    def modify_host_config(opts)
      host_config = opts['HostConfig'] || {}
      dns = interface_ip('docker0')
      if dns && host_config['NetworkMode'].to_s != 'host'
        host_config['Dns'] = [dns]
        host_config['DnsSearch'] = ['kontena.local']
        host_config['DnsOptions'] = ['use-vc'] # tcp mode for dns lookups
      end
      opts['HostConfig'] = host_config
    end

    # @param [Array<String>] cmd
    def exec(cmd)
      begin
        container = Docker::Container.create(
          'Image' => weave_exec_image,
          'Cmd' => cmd,
          'Volumes' => {
            '/var/run/docker.sock' => {},
            '/host' => {}
          },
          'Labels' => {
            'io.kontena.container.skip_logs' => '1'
          },
          'Env' => [
            'HOST_ROOT=/host',
            "VERSION=#{WEAVE_VERSION}"
          ],
          'HostConfig' => {
            'Privileged' => true,
            'NetworkMode' => 'host',
            'PidMode' => 'host',
            'Binds' => [
              '/var/run/docker.sock:/var/run/docker.sock',
              '/:/host'
            ]
          }
        )
        retries = 0
        response = {}
        begin
          response = container.tap(&:start).wait
        rescue Docker::Error::NotFoundError => exc
          error exc.message
          return false
        rescue => exc
          retries += 1
          error exc.message
          sleep 0.5
          retry if retries < 10

          error exc.message
          return false
        end
        response
      ensure
        container.delete(force: true, v: true) if container
      end
    end

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      async.start(info)
    end

    # @param [Hash] info
    def start(info)
      sleep 1 until images_exist?

      weave = Docker::Container.get('weave') rescue nil
      if weave && weave.info['Config']['Image'].split(':')[1] != WEAVE_VERSION
        weave.delete(force: true)
      end

      weave = nil
      peer_ips = info['peer_ips'] || []
      trusted_subnets = info.dig('grid', 'trusted_subnets')
      until weave && weave.running? do
        exec_params = [
          '--local', 'launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local',
          '--password', ENV['KONTENA_TOKEN']
        ]
        exec_params += ['--trusted-subnets', trusted_subnets.join(',')] if trusted_subnets
        self.exec(exec_params)
        weave = Docker::Container.get('weave') rescue nil
        wait = Time.now.to_f + 10.0
        sleep 0.5 until (weave && weave.running?) || (wait < Time.now.to_f)

        if weave.nil? || !weave.running?
          self.exec(['--local', 'reset'])
        end
      end

      connect_peers(peer_ips)
      info "using trusted subnets: #{trusted_subnets.join(',')}" if trusted_subnets && !already_started?
      # Start the weavemesh plugin
      plugin = nil
      until plugin && plugin.running? do
        exec_params = [
          '--local', 'launch-plugin'
        ]
        self.exec(exec_params)
        plugin = Docker::Container.get('weaveplugin') rescue nil
        wait = Time.now.to_f + 10.0
        sleep 0.5 until (plugin && plugin.running?) || (wait < Time.now.to_f)

      end
      ensure_kontena_network
      post_start(info) unless already_started?

      @started = true
      info
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      debug exc.backtrace.join("\n")
    end

    # @param [Array<String>] peer_ips
    def connect_peers(peer_ips)
      if peer_ips.size > 0
        self.exec(['--local', 'connect', '--replace'] + peer_ips)
        info "router connected to peers #{peer_ips.join(', ')}"
      else
        info "router does not have any known peers"
      end
    end

    # @param [Hash] info
    def post_start(info)
      if info['node_number']
        weave_bridge = "10.81.0.#{info['node_number']}/19"
        self.exec(['--local', 'expose', "ip:#{weave_bridge}"])
        info "bridge exposed: #{weave_bridge}"
      end
      Celluloid::Notifications.publish('network_adapter:start', info)
    end

    def detach_network(container)
      self.exec(['--local', 'detach', container.id])
    end

    private

    def ensure_kontena_network
      kontena_network = Docker::Network.get('kontena') rescue nil
      unless kontena_network
        info "creating default kontena network..."
        opts = {
          'Driver': 'weavemesh',
          'IPAM': {
            'Driver': 'kontena-ipam',
            'Config': [
              {
                # Need to set the subnet for the default network so we can
                # later migrate container to it with manually set IP's
                'Subnet': '10.81.0.0/16'
              }
            ],
            'Options': {
              'network': 'kontena'
            }
          }
        }
        network = Docker::Network.create('kontena', opts)
        info "..done. network id: #{network.id}"
      end
    end

    def ensure_images
      images = [
        weave_image,
        weave_exec_image
      ]
      images.each do |image|
        unless Docker::Image.exist?(image)
          info "pulling #{image}"
          Docker::Image.create({'fromImage' => image})
          sleep 1 until Docker::Image.exist?(image)
          info "image #{image} pulled "
        end
      end
      @images_exist = true
    end

  end
end
