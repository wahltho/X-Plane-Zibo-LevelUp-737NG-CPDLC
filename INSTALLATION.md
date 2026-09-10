# Installation

1. Close X-Plane.
2. Unpack the release archive anywhere outside the aircraft folder.
3. Run `python3 z_Install.py check --aircraft-root "<aircraft root>"`. The
   aircraft root is the folder containing `plugins/xlua/scripts`.
4. Run `python3 z_Install.py install --aircraft-root "<aircraft root>"`.
5. Start X-Plane.

`verify` reports the installed state. `uninstall` restores the owned blocks
and keeps unrelated local changes. A backup of the original file is stored in
`.zibo-cpdlc-patch/backups/` inside the aircraft root.

After an aircraft update, run `check` again: a changed owned block is
reported before anything is written.
