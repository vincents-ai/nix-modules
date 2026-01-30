{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.vincents-ai.common-troubleshooting or { };

  defaultTrees = {
    network-connectivity = {
      id = "network-connectivity";
      title = "Network Connectivity Issues";
      startNode = "check-interfaces";
      nodes = {
        check-interfaces = {
          type = "check";
          description = "Checking network interfaces";
          command = "ip link show up | grep -q 'state UP'";
          pass = "check-internet";
          fail = "action-bring-up";
        };
        check-internet = {
          type = "check";
          description = "Checking internet connectivity";
          command = "ping -c 1 8.8.8.8 >/dev/null 2>&1";
          pass = "result-ok";
          fail = "check-dns";
        };
        check-dns = {
          type = "check";
          description = "Checking DNS resolution";
          command = "nslookup google.com >/dev/null 2>&1";
          pass = "result-firewall";
          fail = "result-dns-fail";
        };
        action-bring-up = {
          type = "action";
          text = "Interfaces are down. Attempting to bring them up.";
          command = "systemctl restart systemd-networkd";
          next = "check-interfaces";
        };
        result-ok = {
          type = "result";
          text = "Network appears to be working correctly.";
        };
        result-dns-fail = {
          type = "result";
          text = "Internet is reachable, but DNS is failing. Check /etc/resolv.conf or DNS server settings.";
        };
        result-firewall = {
          type = "result";
          text = "Internet is reachable and DNS works. If specific services fail, check firewall rules.";
        };
      };
    };
  };
in
{
  options.vincents-ai.common-troubleshooting = with lib; {
    enable = mkEnableOption "Troubleshooting Decision Trees";

    trees = mkOption {
      type = types.attrsOf types.attrs;
      default = defaultTrees;
      description = "Defined troubleshooting decision trees";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.iproute2
      pkgs.iputils
      pkgs.dnsutils
    ];

    environment.etc."vincentsai-diagnose.bash".text = ''
      #!/bin/bash

      if [ "$1" == "list" ]; then
        echo "Available Diagnostic Trees:"
        echo "---------------------------"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (id: tree: ''
            echo "${id} - ${tree.title}"
          '') cfg.trees
        )}
        exit 0
      fi

      TREE_ID=$1
      if [ -z "$TREE_ID" ]; then
        echo "Usage: vincentsai-diagnose [list|<tree-id>]"
        exit 1
      fi

      TREE=''${cfg.trees.${TREE_ID} or {}}
      if [ -z "$TREE" ] || [ -z ''${TREE.nodes or {}} ]; then
        echo "Diagnostic tree not found: $TREE_ID"
        exit 1
      fi

      echo "Running diagnostic: $TREE_ID"
      echo "Title: $TREE.title"
      echo "---"

      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (nodeId: node: ''
          echo "Node: $nodeId"
          echo "Type: $node.type"
          if [ -n "$node.description" ]; then
            echo "Description: $node.description"
          fi
          if [ -n "$node.command" ]; then
            echo "Command: $node.command"
          fi
          if [ -n "$node.text" ]; then
            echo "Message: $node.text"
          fi
          if [ -n "$node.pass" ]; then
            echo "On Pass: $node.pass"
          fi
          if [ -n "$node.fail" ]; then
            echo "On Fail: $node.fail"
          fi
          echo "---"
        '') cfg.trees.${TREE_ID}.nodes or {}
      )}
    '';

    environment.systemPackages = [
      (pkgs.writeScriptBin "vincentsai-diagnose" ''
        #!/bin/bash

        if [ "$1" == "list" ]; then
          echo "Available Diagnostic Trees:"
          echo "---------------------------"
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (id: tree: ''
              echo "${id} - ${tree.title}"
            '') cfg.trees
          )}
          exit 0
        fi

        TREE_ID=$1
        if [ -z "$TREE_ID" ]; then
          echo "Usage: vincentsai-diagnose [list|<tree-id>]"
          exit 1
        fi

        echo "Running diagnostic: $TREE_ID"
        echo "Title: $TREE_ID"
        echo "---"
      '')
    ];
  };
}
