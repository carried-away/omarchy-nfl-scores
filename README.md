# Omarchy NFL Live Scores

An Omarchy shell bar widget that shows live NFL scores in a compact,
two-column grid.

## Features

- Live game status, quarter/time, broadcast network, and scores.
- ESPN team logos.
- A football icon beside the team with possession.
- Automatic refresh every 30 seconds.
- Cached scores when ESPN is temporarily unavailable.
- Scrollable layout for busy game days.

## Installation

```bash
omarchy plugin add https://github.com/carried-away/omarchy-nfl-scores.git --enable
```

The widget is placed in the center section of the bar by default. Click the
`NFL` bar button to open the scoreboard. Middle-click refreshes it immediately.

## Removal

```bash
omarchy plugin remove ray.nflscores
```

## Dependencies

The plugin uses tools included with a standard Omarchy installation:

- `bash`
- `curl`
- `jq`

Scores and team logos are provided by ESPN's public API. No account or API key
is required.

## License

MIT. See [LICENSE](LICENSE).
