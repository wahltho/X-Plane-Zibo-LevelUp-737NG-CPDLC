# Installation

1. Close X-Plane.
2. Unpack the release archive anywhere outside the aircraft folder.
3. Run `python3 z_Install.py check --aircraft-root "<aircraft root>"`. The
   aircraft root is the folder containing `plugins/xlua/scripts`.
4. Run `python3 z_Install.py install --aircraft-root "<aircraft root>"`.
5. Start X-Plane.

For an existing standalone 1.1.0 installation, run `check` and `install` from
the unpacked 1.2.0 folder. Maintenance Toolkit installations are updated with
the Toolkit's normal Update action.

`verify` reports the installed state. `uninstall` restores the owned blocks
and keeps unrelated local changes. A backup of the original file is stored in
`.zibo-cpdlc-patch/backups/` inside the aircraft root.

After an aircraft update, run `check` again: a changed owned block is
reported before anything is written.

## Installation ownership

MTK and the standalone installer remain separate supported installation methods.
Use the same owner for updates and removal. To switch, uninstall through the
current owner first, then install through the other. Neither installer adopts
already patched files on the strength of matching hashes alone.

Keep the complete extracted package, including `standalone_guard.py` and
`standalone-ownership.json`. The standalone installer checks its recorded
original backups and stops if MTK owns this patch or a shared target file.
Unknown, duplicate or incomplete patch blocks and unowned companion files also
block the operation. Other correctly installed patches are preserved.

A failed operation restores the bytes it changed. If the process is interrupted,
keep the `.patch-ownership` receipt, transaction journal and lock, together with
any older patch backup/state directory. Do not delete them to retry. Ask for
support before changing those files.

Older standalone installs without a complete receipt are not automatically
migrated. Remove them using the installer and original backups that created
them. This source change affects installation checks only; runtime payloads and
patch versions are unchanged. Installer and recovery tests cover these checks.
