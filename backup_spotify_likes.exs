Mix.install([
  {:req, "~> 0.1.0-dev", github: "wojtekmach/req", branch: "main"}
])

defmodule Main do
  @spotify_token System.get_env("SPOTIFY_TOKEN")
  @spotify_likes_endpoint "https://api.spotify.com/v1/me/tracks"

  def make_get_request(spotify_api_address) do
    Req.build(
      :get,
      spotify_api_address,
      headers: [{"Authorization", "Bearer #{@spotify_token}"}]
    )
    |> Req.add_response_steps([&Req.decode/2])
    |> Req.run()
  end

  def request_tracks(track_list \\ [], next_address)

  def request_tracks(track_list, next_address) when is_bitstring(next_address) do
    {:ok, response_data} = make_get_request(next_address)

    case response_data.status do
      401 ->
        IO.puts("Response status 401. Make sure Spotify Token is still valid!")
        []

      200 ->
        next_track_list = response_data.body["items"]
        next_address = response_data.body["next"]

        merged_track_list = track_list ++ next_track_list

        request_tracks(merged_track_list, next_address)
    end
  end

  def request_tracks(track_list, next_address) when is_nil(next_address), do: track_list

  def parse_tracks(tracks_list) do
    Enum.map(tracks_list, fn track_data ->
      %{
        :title => track_data["track"]["name"],
        :artists => parse_artists(track_data["track"]["artists"])
      }
    end)
  end

  def parse_artists(artists) do
    Enum.reduce(artists, "", fn artist, acc -> acc <> "#{artist["name"]}," end)
    |> String.trim(",")
  end

  def write_tracks_to_file(tracklist) do
    file_name = create_timestamped_file()
    file = File.open!(file_name, [:write, :utf8])
    IO.write(file, "\"track_name\",\"artists\"\r\n")

    tracklist
    |> Enum.each(fn track ->
      IO.write(file, "\"#{track.title}\",\"#{track.artists}\"\r\n")
    end)
  end

  def create_timestamped_file() do
    timestamp = :os.system_time(:millisecond)
    file_name = "spotify_likes_#{timestamp}.csv"
    File.touch!(file_name)
    file_name
  end

  def main do
    request_tracks(@spotify_likes_endpoint)
    |> parse_tracks()
    |> write_tracks_to_file()
  end
end

Main.main()
