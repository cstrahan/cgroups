{ haskellPackages ? (import <nixpkgs> {}).haskellPackages }:
let
  inherit (haskellPackages)
    cabal
    cabalInstall
    aeson
    conduit
    conduitCombinators
    httpTypes
    network
    scotty
    systemFileio
    systemFilepath
    text
    transformers
    wai
    waiHandlerFastcgi;
in 
  cabal.mkDerivation (self: {
    pname = "cgroups";
    version = "1.0.0";
    isLibrary = false;
    isExecutable = true;
    src = ./.;
    buildDepends = [
        aeson
        conduit
        conduitCombinators
        httpTypes
        network
        scotty
        systemFileio
        systemFilepath
        text
        transformers
        wai
        waiHandlerFastcgi
    ];
    buildTools = [ cabalInstall ];
    enableSplitObjs = false;
  })
