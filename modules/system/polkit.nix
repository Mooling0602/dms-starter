{ ... }:

{
  # gpu-screen-recorder escalates its KMS helper through pkexec: the nixpkgs
  # wrapper prepends /run/wrappers/bin to PATH and the binary execs pkexec, so
  # the passwordless rule in the desktop layers only has an effect when that
  # wrapper exists. This nixpkgs keeps it opt in
  # (security.polkit.enablePkexecWrapper defaults to false), so it is enabled
  # here, and every call still passes through polkit: an action only proceeds
  # when a rule grants it or the authentication agent approves a prompt.
  #
  # See MAINTENANCE.md, "setuid pkexec wrapper", for the reason and the
  # conditions under which this can be dropped again.
  security.polkit.enablePkexecWrapper = true;
}
