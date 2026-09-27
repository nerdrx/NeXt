# NeXt validation

Run every graphical development or test launch inside hidden Gamescope. Never
launch bare `./run-next.sh` or the graphical editor during automated validation;
the user must not receive test windows on their desktop.

```sh
timeout -k 3 45 gamescope --backend headless -W 1440 -H 900 -- ./run-next.sh --audio-driver Dummy -s tests/TEST.gd -- --capture-only
```

For parse/import checks use `./run-next.sh --headless --editor --import --quit`.
Bound script tests with `timeout` because failed Godot assertions can leave the
process running. Inspect failures and stop the owned process before retrying.
Do not stop unrelated user sessions. With RTK, use `rtk proxy` around these
commands so the complete command and arguments reach the launcher.
