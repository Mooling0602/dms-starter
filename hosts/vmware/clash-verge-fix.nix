{ pkgs, ... }:

{
  # Mihomo's TUN in auto-route mode inserts policy rules such as
  # `priority 9002: from all lookup 2022`, hijacking all local IPv6 traffic
  # into the TUN. Direct IPv6 then breaks, and cloudflare_ddns cannot read the
  # public address: its probes to public IPv6 endpoints are proxied, then it
  # falls back to the local NIC and writes the TUN fake address
  # fdfe:dcba:9876::1 into the AAAA record.
  #
  # Insert a higher-priority rule ahead of mihomo's own range (9000-9010) so
  # IPv6 resolves through the main table again. Verified: direct IPv6 and DDNS
  # recover while the TUN stays up, and mihomo stop/restart/reload does not
  # remove the rule, it only clears its own 9000-9010 range.
  systemd.services.clash-verge-ipv6-bypass = {
    description = "Route IPv6 directly, bypassing Mihomo TUN policy routing";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.runtimeShell} -c \"${pkgs.iproute2}/bin/ip -6 rule del priority 8994 2>/dev/null || true ; ${pkgs.iproute2}/bin/ip -6 rule add from all lookup main priority 8994\"";
      ExecStop = "${pkgs.runtimeShell} -c \"${pkgs.iproute2}/bin/ip -6 rule del priority 8994 2>/dev/null || true\"";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
