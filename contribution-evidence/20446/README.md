# Run score modifier visual evidence

These are unedited screenshots of the actual Settings UI built from PR #51195 source commit `6ae2d78581a8f8c04f3f648c93d63a84e676c5a6` in Windows validation run https://github.com/muhammadmahadazher/PowerToys/actions/runs/38238188580.

For safe manual testing, the debug build redirects settings and logs through `POWERTOYS_UI_VALIDATION_ROOT` and opens the Run page on startup. The isolation patch and source commit are included in that run's evidence artifact. The score control and its view model are unchanged beyond the PR's minimum/maximum change. A sample Program plugin is loaded from the isolated settings directory; this is not a complete installed Runner session.

The runtime host was renamed to `PowerToys.RunSettings.Validation.exe`, with a matching renamed PRI, to avoid a capture-tool collision with Windows Settings. It loads the original built Settings assembly.

Both values were entered through the UI and committed by moving focus away. Subsequent accessibility snapshots verified the NumberBox's numeric value, not only its edit text. The corresponding `.txt` files record these observations. The desktop dimmer affects screenshot brightness; images have not been edited or reconstructed.

The isolated sample was reset to zero and the test application was closed after capture. Ranking behavior is covered separately by the repository Wox tests.
