{
  description = "Flake for the agl-report-reader application";
  
  nixConfig = {
    substituters = [
        "https://cache.nixos.org"
        "https://cuda-maintainers.cachix.org"
      ];
    trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    extra-substituters = "https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org";
    extra-trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=";
  };

  inputs = {
    # Use a single nixpkgs input to avoid conflicts
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # poetry2nix should follow the same nixpkgs
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs";

    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, poetry2nix, ... } @ inputs: 

  let 
    system = "x86_64-linux";
    self = inputs.self;
    version = "0.1.${pkgs.lib.substring 0 8 inputs.self.lastModifiedDate}.${inputs.self.shortRev or "dirty"}";
    python_version = "311";
    cachix = inputs.cachix;

    nvidiaCache = cachix.lib.mkCachixCache {
      inherit (pkgs) lib;
      name = "nvidia";
      publicKey = "nvidia.cachix.org-1:dSyZxI8geDCJrwgvBfPH3zHMC+PO6y/BT7O6zLBOv0w=";
      secretKey = null;  # not needed for pulling from the cache
    };
  
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    lib = pkgs.lib;

    pypkgs-build-requirements = {
      gender-guesser = [ "setuptools" ];
      conllu = [ "setuptools" ];
      janome = [ "setuptools" ];
      pptree = [ "setuptools" ];
      wikipedia-api = [ "setuptools" ];
      django-flat-theme = [ "setuptools" ];
      django-flat-responsive = [ "setuptools" ];
    };

    poetry2nix = inputs.poetry2nix.lib.mkPoetry2Nix { inherit pkgs;};

    p2n-overrides = poetry2nix.defaultPoetryOverrides.extend (final: prev:
      builtins.mapAttrs (package: build-requirements:
        (builtins.getAttr package prev).overridePythonAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ (
            builtins.map (pkg:
              if builtins.isString pkg then builtins.getAttr pkg prev else pkg
            ) build-requirements
          );
        })
      ) pypkgs-build-requirements
    );

    poetryApp = poetry2nix.mkPoetryApplication {
      projectDir = ./.;
      src = lib.cleanSource ./.;
      python = pkgs."python${python_version}";
      overrides = p2n-overrides;
      preferWheels = true; # some packages, e.g. transformers break if false
      propagatedBuildInputs =  with pkgs."python${python_version}Packages"; [];
      nativeBuildInputs = with pkgs."python${python_version}Packages"; [
        pip
        setuptools
        icecream
      ];
      # postShellHook = ''
      #   python manage.py migrate  
      # '';
    };
    
  in
  {

    packages.x86_64-linux.poetryApp = poetryApp;
    packages.x86_64-linux.default = poetryApp;

    # apps.x86_64-linux.default = {
    #   type = "app";
    #   program = "${poetryApp}/bin/django-server";
    # };

    devShells.x86_64-linux.default = pkgs.mkShell {
      inputsFrom = [ self.packages.x86_64-linux.poetryApp ];
      packages = [ pkgs.poetry ];
    };

  };
}
