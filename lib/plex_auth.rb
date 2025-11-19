require "http"
require "json"
require "securerandom"
require "cgi"
require "openssl"
require "fileutils"

module PlexMediaServerExporter
  class PlexAuth
    PLEX_API_URL = "https://plex.tv/api/v2"
    PLEX_AUTH_APP_URL = "https://app.plex.tv/auth"

    attr_reader :client_id, :product_name

    def initialize(product_name: "Plex Media Server Prometheus Exporter", auth_file_path: nil)
      @product_name = product_name
      @auth_file_path = auth_file_path || ENV["PLEX_AUTH_FILE"] || File.expand_path("~/.plex_exporter_auth")
      @client_id = load_or_generate_client_id
      @ssl_options = build_ssl_options
    end

    # Get a valid access token, prompting for authentication if needed
    def get_access_token
      # Try to load stored token
      stored_token = load_stored_token

      if stored_token && verify_token(stored_token)
        log "Using stored access token"
        return stored_token
      end

      # Need to authenticate
      log "No valid token found, starting authentication flow..."
      authenticate
    end

    # Verify if a token is valid
    def verify_token(token)
      return false unless token

      response = HTTP
        .headers(
          "accept" => "application/json",
          "X-Plex-Product" => @product_name,
          "X-Plex-Client-Identifier" => @client_id,
          "X-Plex-Token" => token
        )
        .get("#{PLEX_API_URL}/user", ssl: @ssl_options)

      response.status == 200
    rescue HTTP::Error
      false
    end

    private

    def build_ssl_options
      # Use system's default certificate store
      store = OpenSSL::X509::Store.new
      store.set_default_paths

      { verify_mode: OpenSSL::SSL::VERIFY_PEER, cert_store: store }
    end

    def authenticate
      pin_data = create_pin
      pin_id = pin_data["id"]
      pin_code = pin_data["code"]

      auth_url = build_auth_url(pin_code)

      puts "\n" + "=" * 80
      puts "PLEX AUTHENTICATION REQUIRED"
      puts "=" * 80
      puts "\nPlease visit this URL to authenticate:"
      puts "\n  #{auth_url}\n"
      puts "\nWaiting for authentication..."
      puts "=" * 80 + "\n"

      # Poll for authentication completion
      token = poll_for_token(pin_id, pin_code)

      if token
        save_token(token)
        log "Authentication successful!"
        token
      else
        raise "Authentication failed or timed out"
      end
    end

    def create_pin
      response = HTTP
        .headers(
          "accept" => "application/json",
          "X-Plex-Product" => @product_name,
          "X-Plex-Client-Identifier" => @client_id
        )
        .post("#{PLEX_API_URL}/pins?strong=true", ssl: @ssl_options)

      JSON.parse(response.body)
    end

    def build_auth_url(pin_code)
      params = {
        clientID: @client_id,
        code: pin_code,
        "context[device][product]" => @product_name
      }

      query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
      "#{PLEX_AUTH_APP_URL}#?#{query_string}"
    end

    def poll_for_token(pin_id, pin_code, timeout: 300)
      start_time = Time.now

      loop do
        if Time.now - start_time > timeout
          log "Authentication timed out"
          return nil
        end

        response = HTTP
          .headers(
            "accept" => "application/json",
            "X-Plex-Client-Identifier" => @client_id
          )
          .get("#{PLEX_API_URL}/pins/#{pin_id}?code=#{pin_code}", ssl: @ssl_options)

        pin_status = JSON.parse(response.body)

        if pin_status["authToken"]
          return pin_status["authToken"]
        end

        sleep 1
      end
    rescue HTTP::Error => e
      log "Error polling for token: #{e.message}"
      nil
    end

    def load_or_generate_client_id
      auth_data = load_auth_data

      if auth_data && auth_data["client_id"]
        auth_data["client_id"]
      else
        client_id = SecureRandom.uuid
        save_client_id(client_id)
        client_id
      end
    end

    def load_stored_token
      auth_data = load_auth_data
      auth_data&.dig("access_token")
    end

    def save_token(token)
      auth_data = load_auth_data || {}
      auth_data["access_token"] = token
      save_auth_data(auth_data)
    end

    def save_client_id(client_id)
      auth_data = load_auth_data || {}
      auth_data["client_id"] = client_id
      save_auth_data(auth_data)
    end

    def load_auth_data
      return nil unless File.exist?(@auth_file_path)

      JSON.parse(File.read(@auth_file_path))
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end

    def save_auth_data(data)
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(@auth_file_path))

      File.write(@auth_file_path, JSON.pretty_generate(data))
      File.chmod(0600, @auth_file_path) # Make file readable/writable only by owner
    end

    def log(message)
      puts "[PlexAuth] #{message}"
    end
  end
end
