require 'base64'

module Music
  class SpotifyApi < ApiInterface
    API_ENDPOINT = 'https://api.spotify.com/v1/'

    SCOPES = ['playlist-read-private', 'playlist-read-collaborative', 'playlist-modify-public', 'playlist-modify-private']

    def initialize(access_token)
      @access_token = access_token

      @spotify_api = Faraday.new(:url => API_ENDPOINT)
      @spotify_api.headers['Authorization'] = "Bearer #{access_token}"
      @spotify_api.headers['Content-Type'] = 'application/json'
    end

    def search(query)
      res = @spotify_api.get 'search', { q: query, type: 'track' }
      body = JSON.parse(res.body)
      puts body
      body['tracks']['items'].map { |track|
        {
          id: track['uri'],
          artists: track['artists'].map { |artist| { name: artist['name'], id: artist['id']} },
          album: {
            name: track['album']['name'],
            jacket_url: track['album']['images'].first['url'],
          },
          name: track['name'],
          duration: (track['duration_ms'] / 1000).ceil,
        }
      }
    end

    def get_playlists()
      res = @spotify_api.get 'me/playlists'
      body = JSON.parse(res.body)
      body['items'].map { |playlist|
        image_url = playlist['images'].first['url'] if playlist['images'].first != nil
        {
          id: playlist['id'],
          name: playlist['name'],
          image_url: image_url,
          description: playlist['description'],
          owner: {
            id: playlist['owner']['id'],
            name: playlist['owner']['display_name'],
          }
        }
      }
    end

    def get_playlist(playlist_id)
      res = @spotify_api.get "playlists/#{playlist_id}"
      body = JSON.parse(res.body)
      image_url = body['images'].first['url'] if body['images'].first != nil

      {
        id: body['id'],
        name: body['name'],
        description: body['description'],
        image_url: image_url,
        owner: {
          id: body['owner']['id'],
          name: body['owner']['display_name']
        }
      }
    end

    def get_playlist_tracks(playlist_id)
      res = @spotify_api.get "playlists/#{playlist_id}/tracks"
      body = JSON.parse(res.body)
      body
      body['items'].map { |item|
        track = item['track']
        {
          id: track['uri'],
          artists: track['artists'].map { |artist| { name: artist['name'], id: artist['id']} },
          album: {
            name: track['album']['name'],
            jacket_url: track['album']['images'].first['url'],
          },
          name: track['name'],
          duration: (track['duration_ms'] / 1000).ceil,
        }
      }
    end

    def create_playlist(name)
      profile = JSON.parse((@spotify_api.get "me").body)
      data = {
        name: name,
        description: "Generated by DJ Gassi",
        public: false
      }
      res = @spotify_api.post "users/#{profile['id']}/playlists", JSON.generate(data)
      body = JSON.parse(res.body)
    end

    def add_track_to_playlist(playlist_id, track_id)
      data = {
        uris: [
          track_id
        ]
      }
      res = @spotify_api.post "playlists/#{playlist_id}/tracks", JSON.generate(data)
      body = JSON.parse(res.body)
    end

    def remove_track_from_playlist(playlist_id, track_id)
      data = {
        tracks: [
          {
            uri: track_id
          }
        ]
      }
      puts data
      res = @spotify_api.run_request :delete, "playlists/#{playlist_id}/tracks", JSON.generate(data), {}
      body = JSON.parse(res.body)
    end

    class << self
      def get_oauth_url(redirect_uri)
        query = {
          response_type: 'code',
          client_id: ENV['SPOTIFY_API_CLIENT_ID'],
          scope: SCOPES.join(' '),
          redirect_uri: redirect_uri,
          state: SecureRandom.hex(16)
        }
        
        'https://accounts.spotify.com/authorize?' + query.to_param
      end

      def get_token_by_code(code, redirect_uri)
        if code === nil || code === ""
          raise ArgumentError, "invalid code"
        end

        params = {
          code: code,
          redirect_uri: redirect_uri,
          grant_type: 'authorization_code'
        }

        res = Faraday.new.post do |req|
          req.headers["Authorization"] = 'Basic ' + Base64.strict_encode64(ENV['SPOTIFY_API_CLIENT_ID'] + ':' + ENV['SPOTIFY_API_CLIENT_SECRET'])
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.url 'https://accounts.spotify.com/api/token'
          req.body = params.to_query
        end

        return JSON.parse(res.body)
      end
    end
  end
end