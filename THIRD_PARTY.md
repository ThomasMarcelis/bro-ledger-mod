# Third-party notices

Bro Ledger's original Squirrel, JavaScript, CSS, tests, and documentation are licensed under [MIT](LICENSE).

Battle Brothers and its assets belong to Overhype Studios. This repository and its release ZIP do not include game binaries, scripts, decompiled source, art, icons, fonts, or saves. Runtime asset paths refer to files in the player's installation.

## Required frameworks

The frameworks are not bundled. Obtain them from their maintainers and retain their licenses.

| Project | Development pin | Inspected ZIP SHA-256 |
| --- | --- | --- |
| [Modern Hooks](https://github.com/MSUTeam/Modern-Hooks/tree/d3c57b2b95486e016afe612d8f3cb0f58e91a48f) | 0.6.0, commit `d3c57b2b95486e016afe612d8f3cb0f58e91a48f` | `18fbf059480a09483693b8eef9c97c3a32450885b1971dda49b5cc14a66d7ed1` |
| [MSU](https://github.com/MSUTeam/MSU/tree/6967cd1c0ce7663e6f938886e050cec3c5d04e81) | 1.9.0, commit `6967cd1c0ce7663e6f938886e050cec3c5d04e81` | `617af64bd4b354408b91f8b8618f94f664491edcd2cf4649b8ad52673c81b37b` |

## Development tool

Local tests use the public [Squirrel](https://github.com/albertodemichelis/squirrel) source at commit `f92bc298784ceea459b12e2de33bdff672bfeb83`. Its executable and COPYRIGHT file stay under ignored `.tools/` and are excluded from the release ZIP.

## Strategy provenance

Earlier versions included a tactical catalog derived from the project's original web implementation and researched using the Battle Brothers wiki, Bloodngold's summaries, and community perk guides. That catalog is retired; the current library starts empty and players author their own builds. Those sources' prose, artwork, and code are not redistributed. [Strategy](docs/STRATEGY.md) describes the current evaluator and its limits.
