require 'rack/auth/basic'

module Rack
  module OAuth2
    module Server
      class Token < Abstract::Handler
        def call(env)
          request = Request.new(env)
          request.profile.new(&@authenticator).call(env).finish
        rescue Rack::OAuth2::Server::Abstract::Error => e
          e.finish
        end

        class Request < Abstract::Request
          attr_required :grant_type
          attr_optional :client_secret

          def initialize(env)
            auth = Rack::Auth::Basic::Request.new(env)
            if auth.provided? && auth.basic?
              @client_id, @client_secret = auth.credentials
              super
            else
              super
              @client_secret = params['client_secret']
            end
            @grant_type = params['grant_type']
          end

          def profile
            case params['grant_type'].to_s
            when 'authorization_code'
              AuthorizationCode
            when 'password'
              Password
            when 'client_credentials'
              ClientCredentials
            when 'refresh_token'
              RefreshToken
            when ''
              attr_missing!
            else
              unsupported_grant_type!("'#{params['grant_type']}' isn't supported.")
            end
          end
        end

        class Response < Abstract::Response
          attr_required :access_token, :token_type
          attr_optional :expires_in, :refresh_token, :scope

          def protocol_params
            {
              :access_token => access_token,
              :token_type => token_type,
              :expires_in => expires_in,
              :scope => Array(scope).join(' ')
            }
          end

          def finish
            write Util.compact_hash(protocol_params).to_json
            header['Content-Type'] = "application/json"
            attr_missing!
            super
          end
        end
      end
    end
  end
end

require 'rack/oauth2/server/token/error'
require 'rack/oauth2/server/token/authorization_code'
require 'rack/oauth2/server/token/password'
require 'rack/oauth2/server/token/client_credentials'
require 'rack/oauth2/server/token/refresh_token'