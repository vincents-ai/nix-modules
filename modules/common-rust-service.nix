# nix-modules/modules/common-rust-service.nix
#
# Advanced Rust service building module for vincents-ai projects.
# Encapsulates patterns from synapse-platform including:
# - Multi-architecture builds (x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin)
# - Crane integration for efficient caching and building
# - Cross-compilation support
# - UPX binary compression with performance measurements
# - SBOM generation (SPDX format)
# - OCI image building with SBOM integration
# - Kubernetes manifest generation
# - License signing with YubiKey support
# - Multi-environment builds (production/staging/demo/evaluation)
{ pkgs, lib, crane, rust-overlay, nixpkgs, ... }:

let
  cfg = config.vincents-ai.common-rust-service or { };

  # Supported architectures for multi-arch builds
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  # Supported build environments
  supportedEnvironments = [
    "production"
    "staging"
    "demo"
    "evaluation"
  ];

  # Helper to import nixpkgs for a specific system
  importForSystem = system: import nixpkgs {
    inherit system;
    overlays = [ (import rust-overlay) ];
  };

  # Helper to get crane lib for a specific system
  craneForSystem = system: crane.mkLib (importForSystem system);

  # Default native build inputs for Rust services
  defaultNativeBuildInputs = [
    pkgs.pkg-config
    pkgs.protobuf
    pkgs.protoc-gen-rust
  ];

  # Default build inputs for Rust services
  defaultBuildInputs = [
    pkgs.openssl
    pkgs.pcsclite
  ];

  # Generate UPX compression report script
  mkUpxCompressionScript = { pname, targetSystem }: ''
    echo "=== UPX Compression Report for ${pname} (${targetSystem}) ==="
    ORIGINAL_SIZE=$(stat -c%s "$out/bin/${pname}")
    echo "Original binary size: $ORIGINAL_SIZE bytes ($(echo "scale=2; $ORIGINAL_SIZE/1024/1024" | ${pkgs.bc}/bin/bc) MB)"

    # Test startup time before compression
    echo "Testing startup time before compression..."
    START_TIME=$(${pkgs.coreutils}/bin/date +%s%3N)
    timeout 5s "$out/bin/${pname}" --help >/dev/null 2>&1 || true
    END_TIME=$(${pkgs.coreutils}/bin/date +%s%3N)
    ORIGINAL_STARTUP=$((END_TIME - START_TIME))
    echo "Original startup time: ''${ORIGINAL_STARTUP}ms"

    echo "Compressing ${pname} binary with UPX for ${targetSystem}..."
    ${pkgs.upx}/bin/upx --best --lzma "$out/bin/${pname}"

    COMPRESSED_SIZE=$(stat -c%s "$out/bin/${pname}")
    COMPRESSION_RATIO=$(echo "scale=2; $COMPRESSED_SIZE*100/$ORIGINAL_SIZE" | ${pkgs.bc}/bin/bc)
    SAVINGS=$(echo "scale=2; ($ORIGINAL_SIZE-$COMPRESSED_SIZE)/1024/1024" | ${pkgs.bc}/bin/bc)

    echo "Compressed binary size: $COMPRESSED_SIZE bytes ($(echo "scale=2; $COMPRESSED_SIZE/1024/1024" | ${pkgs.bc}/bin/bc) MB)"
    echo "Compression ratio: ''${COMPRESSION_RATIO}%"
    echo "Space savings: ''${SAVINGS} MB"

    # Test startup time after compression
    echo "Testing startup time after compression..."
    START_TIME=$(${pkgs.coreutils}/bin/date +%s%3N)
    timeout 5s "$out/bin/${pname}" --help >/dev/null 2>&1 || true
    END_TIME=$(${pkgs.coreutils}/bin/date +%s%3N)
    COMPRESSED_STARTUP=$((END_TIME - START_TIME))
    echo "Compressed startup time: ''${COMPRESSED_STARTUP}ms"

    if [ $COMPRESSED_STARTUP -gt $ORIGINAL_STARTUP ]; then
      STARTUP_OVERHEAD=$((COMPRESSED_STARTUP - ORIGINAL_STARTUP))
      echo "Decompression overhead: +''${STARTUP_OVERHEAD}ms"
    else
      echo "No measurable startup overhead"
    fi

    echo "=== UPX Compression Complete for ${targetSystem} ==="
  '';

  # Generate SPDX SBOM JSON
  generateSbomJson = { pname, binary, namespace }:
    let
      version = binary.version or "unknown";
    in
    builtins.toJSON {
      spdxVersion = "SPDX-2.3";
      dataLicense = "CC0-1.0";
      SPDXID = "SPDXRef-DOCUMENT";
      name = "${pname} SBOM";
      documentNamespace = "${namespace}/${pname}/${version}";
      creationInfo = {
        creators = [ "Tool: nix-${pkgs.nix.version}" ];
        created = "1970-01-01T00:00:00Z";
      };
      packages = map
        (pkg: {
          SPDXID = "SPDXRef-${builtins.replaceStrings ["-" "."] ["_" "_"] (pkg.pname or pkg.name or "unknown")}";
          name = pkg.pname or pkg.name or "unknown";
          downloadLocation = "NOASSERTION";
          filesAnalyzed = false;
          version = pkg.version or "unknown";
          supplier = "NOASSERTION";
          homepage = pkg.meta.homepage or "NOASSERTION";
          description = pkg.meta.description or "NOASSERTION";
        })
        (lib.unique (lib.filter (pkg: pkg ? pname || pkg ? name) (lib.flatten [
          binary
          (builtins.filter (dep: dep ? pname || dep ? name)
            (if builtins.isList (binary.buildInputs or [ ])
            then binary.buildInputs
            else lib.attrValues (builtins.removeAttrs (binary.buildInputs or { }) [ "out" ])))
          (builtins.filter (dep: dep ? pname || dep ? name)
            (if builtins.isList (binary.nativeBuildInputs or [ ])
            then binary.nativeBuildInputs
            else lib.attrValues (builtins.removeAttrs (binary.nativeBuildInputs or { }) [ "out" ])))
        ])));
      relationships = [
        {
          spdxElementId = "SPDXRef-DOCUMENT";
          relationshipType = "DESCRIBES";
          relatedSpdxElement = "SPDXRef-${builtins.replaceStrings ["-" "."] ["_" "_"] (binary.pname or binary.name or pname)}";
        }
      ];
    };

in
{
  options.vincents-ai.common-rust-service = with lib; {
    enable = mkEnableOption "Advanced Rust service builder with multi-arch, compression, SBOM, and K8s support";

    supportedSystems = mkOption {
      type = types.listOf types.str;
      default = supportedSystems;
      description = "List of supported systems for multi-arch builds";
    };

    supportedEnvironments = mkOption {
      type = types.listOf types.str;
      default = supportedEnvironments;
      description = "List of supported build environments";
    };

    namespace = mkOption {
      type = types.str;
      default = "https://vincents.ai/sbom";
      description = "SBOM document namespace base URL";
    };

    # Core builder functions
    buildMultiArchRustService = mkOption {
      type = types.raw;
      description = "Function to build a Rust service for all supported architectures";
    };

    buildCrossCompiledRustService = mkOption {
      type = types.raw;
      description = "Function to cross-compile a Rust service for a target system";
    };

    buildCompressedBinary = mkOption {
      type = types.raw;
      description = "Function to build and compress a Rust binary with UPX";
    };

    generateSbom = mkOption {
      type = types.raw;
      description = "Function to generate SPDX SBOM for a binary";
    };

    buildOciImageWithSbom = mkOption {
      type = types.raw;
      description = "Function to build an OCI image with SBOM integration";
    };

    buildKubernetesManifests = mkOption {
      type = types.raw;
      description = "Function to generate Kubernetes manifests from service definitions";
    };

    buildLicenseSigner = mkOption {
      type = types.raw;
      description = "Function to build license signer with YubiKey support";
    };

    buildRustServiceEnv = mkOption {
      type = types.raw;
      description = "Function to build a Rust service for a specific environment";
    };
  };

  config = lib.mkIf cfg.enable {
    vincents-ai.common-rust-service = {
      inherit supportedSystems supportedEnvironments namespace;

      buildMultiArchRustService = { pname, src, cargoExtraArgs ? "", nativeBuildInputs ? [ ], buildInputs ? [ ], preBuild ? "", postInstall ? "" }:
        lib.genAttrs cfg.supportedSystems (targetSystem:
          let
            targetPkgs = importForSystem targetSystem;
            targetCraneLib = craneForSystem targetSystem;
          in
          targetCraneLib.buildPackage {
            inherit pname src;
            cargoExtraArgs = cargoExtraArgs;
            nativeBuildInputs = nativeBuildInputs ++ [ targetPkgs.pkg-config targetPkgs.upx targetPkgs.bc targetPkgs.coreutils ];
            buildInputs = buildInputs ++ [ targetPkgs.openssl ];
            preBuild = preBuild;
            postInstall = mkUpxCompressionScript { inherit pname targetSystem; } + postInstall;
          }
        );

      buildCrossCompiledRustService = { targetSystem, pname, src, cargoExtraArgs ? "", nativeBuildInputs ? [ ], buildInputs ? [ ], preBuild ? "", postInstall ? "" }:
        let
          targetPkgs = importForSystem targetSystem;
          targetCraneLib = craneForSystem targetSystem;
        in
        targetCraneLib.buildPackage {
          inherit pname src;
          cargoExtraArgs = cargoExtraArgs;
          nativeBuildInputs = nativeBuildInputs ++ [ targetPkgs.pkg-config targetPkgs.upx targetPkgs.bc targetPkgs.coreutils ];
          buildInputs = buildInputs ++ [ targetPkgs.openssl ];
          preBuild = preBuild;
          postInstall = mkUpxCompressionScript { inherit pname targetSystem; } + postInstall;
        };

      buildCompressedBinary = { pname, src, version, cargoExtraArgs ? "", nativeBuildInputs ? [ ], buildInputs ? [ ], compress ? true, postInstall ? "" }:
        let
          craneLib = crane.mkLib pkgs;
        in
        craneLib.buildPackage {
          inherit pname src;
          version = version;
          cargoExtraArgs = cargoExtraArgs;
          nativeBuildInputs = nativeBuildInputs ++ defaultNativeBuildInputs ++ lib.optionals compress [ pkgs.upx pkgs.bc pkgs.coreutils ];
          buildInputs = buildInputs ++ defaultBuildInputs;
          postInstall = lib.optionalString compress (mkUpxCompressionScript { inherit pname; targetSystem = pkgs.stdenv.system; }) + postInstall;
        };

      generateSbom = { pname, binary }:
        let
          sbomNamespace = cfg.namespace;
        in
        pkgs.writeTextFile {
          name = "${pname}-sbom.json";
          text = generateSbomJson { pname = pname; binary = binary; namespace = sbomNamespace; };
        };

      buildOciImageWithSbom = { pname, binary, runtimeDeps ? [ pkgs.cacert ], includeSbom ? true, extraLabels ? { }, extraConfig ? { } }:
        let
          sbom = if includeSbom then cfg.generateSbom { inherit pname binary; } else null;
          image = pkgs.dockerTools.buildImage {
            name = "vincents-ai/${pname}";
            tag = binary.version;
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ binary ] ++ runtimeDeps ++ lib.optionals includeSbom [ sbom ];
            };
            config = {
              Cmd = [ "${binary}/bin/${pname}" ];
              Labels = {
                "org.opencontainers.image.title" = "Vincents.ai ${pname}";
                "org.opencontainers.image.description" = "Vincents.ai ${pname} service";
                "org.opencontainers.image.version" = binary.version;
                "org.opencontainers.image.vendor" = "Vincents.ai";
                "org.opencontainers.image.licenses" = "Proprietary";
                "org.opencontainers.image.source" = "https://github.com/vincents-ai";
              } // extraLabels // lib.optionalAttrs includeSbom {
                "org.opencontainers.image.sbom" = "/sbom.json";
              };
            } // extraConfig;
          };
        in
        if includeSbom then
          pkgs.runCommand "${pname}-image-with-sbom" { } ''
            mkdir -p $out
            cp -r ${image}/* $out/
            cp ${sbom} $out/sbom.json
          ''
        else image;

      buildKubernetesManifests = { namespace, services, complianceLib ? null, infrastructureServices ? { }, commonEnv ? { }, extraResources ? [ ] }:
        let
          mkService = { name, port, targetPort, labels ? { } }: {
            apiVersion = "v1";
            kind = "Service";
            metadata = {
              inherit name namespace;
              labels = { "app.kubernetes.io/name" = name; } // labels;
            };
            spec = {
              selector = { "app.kubernetes.io/name" = name; };
              ports = [{ inherit port targetPort; }];
            };
          };

          mkGrpcProbe = port: {
            grpc = { inherit port; service = ""; };
            initialDelaySeconds = 10;
            periodSeconds = 15;
            timeoutSeconds = 5;
            failureThreshold = 3;
          };

          resourceProfiles = {
            small = { requests = { cpu = "100m"; memory = "128Mi"; }; limits = { cpu = "250m"; memory = "256Mi"; }; };
            medium = { requests = { cpu = "250m"; memory = "256Mi"; }; limits = { cpu = "500m"; memory = "512Mi"; }; };
            large = { requests = { cpu = "500m"; memory = "512Mi"; }; limits = { cpu = "1000m"; memory = "1024Mi"; }; };
          };

          allResources =
            [{ apiVersion = "v1"; kind = "Namespace"; metadata = { inherit name namespace; }; }]
            ++ (lib.concatLists (lib.mapAttrsToList (name: service:
              let
                serviceLabels = if complianceLib != null then complianceLib.mkServiceLabels service.profiles else {};
                grpcProbe = mkGrpcProbe service.port;
                deploymentBase = if complianceLib != null then
                  complianceLib.mkComplianceDeployment {
                    inherit name;
                    profiles = service.profiles;
                    serviceConfig = {
                      inherit (service) image port resources;
                      args = service.args or [];
                      environment = lib.mapAttrsToList (n: v: { name = n; value = v; }) commonEnv;
                      livenessProbe = grpcProbe;
                      readinessProbe = grpcProbe;
                    };
                  }
                else {
                  apiVersion = "apps/v1";
                  kind = "Deployment";
                  metadata = { inherit name namespace; labels = { app = name; }; };
                  spec = {
                    replicas = 1;
                    selector = { matchLabels = { app = name; }; };
                    template = {
                      metadata = { labels = { app = name; }; };
                      spec = {
                        containers = [{
                          inherit name;
                          inherit (service) image;
                          ports = [{ containerPort = service.port; }];
                          env = lib.mapAttrsToList (n: v: { name = n; value = v; }) commonEnv;
                          livenessProbe = grpcProbe;
                          readinessProbe = grpcProbe;
                        }];
                      };
                    };
                  };
                };
                deploymentWithOtel = deploymentBase // {
                  spec = deploymentBase.spec // {
                    template = deploymentBase.spec.template // {
                      metadata = deploymentBase.spec.template.metadata // {
                        annotations = (deploymentBase.spec.template.metadata.annotations or {}) // {
                          "prometheus.io/scrape" = "true";
                          "prometheus.io/port" = toString service.port;
                          "prometheus.io/path" = "/metrics";
                        };
                      };
                    };
                  };
                };
              in [
                deploymentWithOtel
                (mkService { inherit name; port = service.port; targetPort = service.port; labels = serviceLabels; })
                (if complianceLib != null then
                  complianceLib.mkJurisdictionNetworkPolicy {
                    inherit name;
                    allowedJurisdictions = service.allowedJurisdictions or [ "GB" "MT" ];
                    blockCrossBorder = false;
                  }
                else { apiVersion = "networking.k8s.io/v1"; kind = "NetworkPolicy"; metadata = { inherit name namespace; }; spec = { podSelector = { }; }; })
              ]
            ) services))
            ++ (lib.mapAttrsToList (name: service: service.deployment) infrastructureServices)
            ++ (lib.mapAttrsToList (name: service: service.service) infrastructureServices)
            ++ extraResources;

          manifestsPackage = let
            yamlFormat = pkgs.formats.yaml { };
          in pkgs.runCommand "kubernetes-manifests" { } ''
            mkdir -p $out
            ${lib.concatStringsSep "\n" (
              lib.imap0 (i: resource:
                let
                  sanitizedName = lib.strings.sanitizeDerivationName resource.metadata.name;
                  fileName = "${toString i}-${resource.kind}-${sanitizedName}.yaml";
                  yamlContentDerivation = yamlFormat.generate fileName resource;
                in
                  "cp ${yamlContentDerivation} $out/${fileName}"
              ) allResources
            )}
          '';
        in
        manifestsPackage;

      buildLicenseSigner = { src, features ? [ ], nativeBuildInputs ? [ ], buildInputs ? [ ], preBuild ? "" }:
        let
          craneLib = crane.mkLib pkgs;
        in
        craneLib.buildPackage {
          pname = "license_signer";
          inherit src;
          cargoExtraArgs = "--package license_signer" + lib.optionalString (features != [ ]) (" --features " + lib.concatStringsSep "," features);
          nativeBuildInputs = nativeBuildInputs ++ defaultNativeBuildInputs;
          buildInputs = buildInputs ++ defaultBuildInputs;
          preBuild = ''
            export LICENSE_SIGNER_BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          '' + preBuild;
        };

      buildRustServiceEnv = { pname, src, environment, configFile ? "./config/license-keys.yaml", nativeBuildInputs ? [ ], buildInputs ? [ ], preBuild ? "" }:
        let
          craneLib = crane.mkLib pkgs;
        in
        craneLib.buildPackage {
          inherit pname src;
          cargoExtraArgs = "--package ${pname}";
          nativeBuildInputs = nativeBuildInputs ++ defaultNativeBuildInputs ++ [ pkgs.yq-go pkgs.sops ];
          buildInputs = buildInputs ++ defaultBuildInputs;
          preBuild =
            ''
              # Extract public key for the specific environment
              if command -v sops >/dev/null 2>&1 && sops -d "${configFile}" >/dev/null 2>&1; then
                export LICENSE_VERIFICATION_PUBLIC_KEY=$(sops -d "${configFile}" | yq ".environments.${environment}.public_key" | tr -d '"')
              else
                export LICENSE_VERIFICATION_PUBLIC_KEY=$(yq ".environments.${environment}.public_key" "${configFile}" | tr -d '"')
              fi

              # Set environment for build
              export LICENSE_VERIFICATION_ENVIRONMENT="${environment}"

              echo "Building ${pname} for environment: ${environment}"
            '' + preBuild;
        };
    };
  };
}
