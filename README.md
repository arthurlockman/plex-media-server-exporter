# plex-media-server-exporter

A better Prometheus exporter for Plex Media Server.

## Usage

```shell
docker run ghcr.io/axsuul/plex-media-server-exporter
```

Metrics endpoint is served by default via `http://localhost:9594/metrics`.

### Authentication

The exporter now uses Plex's official PIN-based OAuth authentication flow. On first run, if no token is found, you'll see output like:

```text
================================================================================
PLEX AUTHENTICATION REQUIRED
================================================================================

Please visit this URL to authenticate:

  https://app.plex.tv/auth#?clientID=...&code=...

Waiting for authentication...
================================================================================
```

Simply visit the URL in your browser, sign in to Plex, and authorize the app. The token will be automatically saved for future use.

**Token Storage:** By default, authentication data is stored in `~/.plex_exporter_auth`. For Docker deployments, you can:

* Mount a volume to persist the auth file: `-v /path/on/host:/auth`
* Set `PLEX_AUTH_FILE=/auth/plex_auth.json` to store the token in the mounted volume

**Backward Compatibility:** You can still use the `PLEX_TOKEN` environment variable if preferred. If set, it will be used instead of the PIN-based authentication flow.

### Environment Variables

These environment variables can be passed into the container (defaults are in parentheses):

* `PORT` (`9594`)
* `PLEX_ADDR` (`http://localhost:32400`)
  * Plex Media Server address
* `PLEX_TOKEN` (optional)
  * Plex Media Server token (if not set, PIN-based authentication will be used)
* `PLEX_AUTH_FILE` (optional, `~/.plex_exporter_auth`)
  * Path where authentication data (client ID and token) will be stored
* `PLEX_TIMEOUT` (`10`)
  * How long to wait for Plex Media Server to respond
* `PLEX_RETRIES_COUNT` (`0`)
  * How many times to retry failed Plex Media Server requests
* `PLEX_SSL_VERIFY` (`true`)
  * Whether to verify the SSL certificate when connecting with HTTPS
* `METRICS_PREFIX` (`plex`)
  * What to prefix metric names with
* `METRICS_MEDIA_COLLECTING_INTERVAL_SECONDS` (`300`)
  * How often to throttle collection of media metrics which can take longer to complete depending on how large of a library you have

## Metrics

Served by default via `http://localhost:9594/metrics`

```prometheus
# TYPE plex_up gauge
# HELP plex_up Server heartbeat
plex_up 1.0
# TYPE plex_info gauge
# HELP plex_info Server diagnostics
plex_info{version="1.29.2.6364-6d72b0cf6"} 1.0
# TYPE plex_media_count gauge
# HELP plex_media_count Number of media in library
plex_media_count{title="Movies",type="movie"} 19318.0
plex_media_count{title="Shows",type="show"} 2318.0
plex_media_count{title="Shows - Episodes",type="show_episode"} 66443.0
plex_media_count{title="Audiobooks",type="artist"} 17.0
plex_media_count{title="Music",type="artist"} 891.0
# TYPE plex_sessions_count gauge
# HELP plex_sessions_count Number of current sessions
plex_sessions_count{state="buffering",user_id="3",username="Tarantino"} 1.0
plex_sessions_count{state="paused",user_id="2",username="Scorsese"} 1.0
plex_sessions_count{state="playing",user_id="3",username="Tarantino"} 1.0
plex_sessions_count{state="playing",user_id="1",username="Hitchcock"} 2.0
# TYPE plex_audio_transcode_sessions_count gauge
# HELP plex_audio_transcode_sessions_count Number of current sessions that are transcoding audio
plex_audio_transcode_sessions_count{state="buffering",user_id="1",username="Hitchcock"} 1.0
plex_audio_transcode_sessions_count{state="paused",user_id="2",username="Scorsese"} 1.0
plex_audio_transcode_sessions_count{state="playing",user_id="3",username="Tarantino"} 1.0
# TYPE plex_video_transcode_sessions_count gauge
# HELP plex_video_transcode_sessions_count Number of current sessions that are transcoding video
plex_video_transcode_sessions_count{state="buffering",user_id="1",username="Hitchcock"} 1.0
plex_video_transcode_sessions_count{state="paused",user_id="2",username="Scorsese"} 1.0
plex_video_transcode_sessions_count{state="playing",user_id="3",username="Tarantino"} 1.0
# TYPE plex_media_downloads_count gauge
# HELP plex_media_downloads_count Number of current media downloads
plex_media_downloads_count{user_id="1",user_id="1",username="Hitchcock"} 1.0
plex_media_downloads_count{user_id="2",user_id="2",username="Scorsese"} 3.0
```

## Grafana

Use this [panel JSON file](examples/grafana/dashboard.json) to import a Grafana dashboard that looks like

![Grafana Dashboard Example](examples/grafana/screenshot.png)
