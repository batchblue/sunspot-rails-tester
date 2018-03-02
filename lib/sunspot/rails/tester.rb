require 'net/http'
require 'forwardable'

module Sunspot
  module Rails
    class Tester
      VERSION = '1.0.0'

      class << self
        extend Forwardable

        attr_accessor :server, :started, :pid

        def start_original_sunspot_session
          unless started?
            self.server = Sunspot::Rails::Server.new
            self.started = Time.now
            self.pid = fork do
              $stderr.reopen('/dev/null')
              $stdout.reopen('/dev/null')
              server.run
              Kernel.exit!
            end
            kill_at_exit
            give_feedback
          end
        end

        def started?
          not server.nil?
        end

        def kill_at_exit
          at_exit do
            Process.kill('TERM', pid)
            p = port.to_s || "8983"
            if server.respond_to?(:exec_in_solr_executable_directory)
              command = ['./solr', 'stop', '-p', p]
              server.exec_in_solr_executable_directory(command)
            end
          end 
        end

        def give_feedback
          puts 'Sunspot server is starting...' while starting
          puts "Sunspot server took #{seconds} seconds to start"
        end

        def starting
          sleep(1)
          res = Net::HTTP.get_response(URI.parse(uri))
          res.code == '503'
        rescue Errno::ECONNREFUSED
          true
        end

        def seconds
          '%.2f' % (Time.now - started)
        end

        def uri
          "http://#{hostname}:#{port}#{path}/ping"
        end

        def_delegators :configuration, :hostname, :port, :path

        def configuration
          server.send(:configuration)
        end

        def clear
          self.server = nil
        end
      end

    end
  end
end
