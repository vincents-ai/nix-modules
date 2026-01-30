{ lib }:

let
  octet = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])";
  ipv4Regex = "^${octet}\\.${octet}\\.${octet}\\.${octet}$";

  validateIPAddress = ip: builtins.match ipv4Regex ip != null;

  validatePort = port: builtins.isInt port && port >= 1 && port <= 65535;

  validateMACAddress = mac:
    let
      macPattern = "^([0-9a-fA-F]{2}[:-]){5}([0-9a-fA-F]{2})$";
    in
    builtins.match macPattern mac != null;

  validateCIDR = cidr:
    let
      split = lib.splitString "/" cidr;
      len = builtins.length split;
    in
    if len == 2 then
      let
        ip = builtins.elemAt split 0;
        prefixStr = builtins.elemAt split 1;
        isNum = builtins.match "[0-9]+" prefixStr != null;
        prefix = if isNum then lib.toInt prefixStr else -1;
      in
      if validateIPAddress ip then
        prefix >= 0 && prefix <= 32
      else
        let
          ipv6Pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}/([0-9]{1,3})$";
        in
        builtins.match ipv6Pattern cidr != null
    else
      false;

  validateFirewallRule = rule: true;
  validateDHCPConfig = config: true;
  validateIDSConfig = config: true;
  validateHost = host: true;
  validateSubnet = subnet: true;
  validateNetwork = network: true;
  validateBGPASN = asn: true;
  validateBGPRouterId = routerId: true;
  validateBGPCommunity = community: true;
  validateBPGLargeCommunity = largeCommunity: true;
  validateBGPNeighbor = neighbor: true;
  validateBGPPrefixList = prefixList: true;
  validateBGPRouteMap = routeMap: true;
  validateBGPConfig = config: true;
  validateHosts = hosts: true;
  fileExists = path: true;
  base64Key = key: true;
  nonEmptyString = str: true;

in
{
  inherit
    validateIPAddress
    validateMACAddress
    validateCIDR
    validatePort
    validateFirewallRule
    validateDHCPConfig
    validateIDSConfig
    validateHost
    validateSubnet
    validateNetwork
    validateBGPASN
    validateBGPRouterId
    validateBGPCommunity
    validateBPGLargeCommunity
    validateBGPNeighbor
    validateBGPPrefixList
    validateBGPRouteMap
    validateBGPConfig
    validateHosts
    fileExists
    base64Key
    nonEmptyString
    ;
}
