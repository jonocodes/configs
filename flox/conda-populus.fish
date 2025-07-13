  echo "Activating conda environment" >&2
  eval /home/jono/.conda/bin/conda "shell.fish" "hook" $argv | source

  conda activate populus-env

  python -V
  pip -V
  conda -V

  # install pdm here to avoid the "Could not install packages due to an OSError: [Errno 30] Read-only file system: 'RECORD'" when installed in [install]
  #  also notice that I do it after loading conda so its in environment
  #  otherwise it often works if I install it in nix globally

  pip install pdm --quiet
	
  pdm -V

  echo READY

  # if conda env not there, create it

  # if node_modules no there, run yarn

  if test ! -d "$FLOX_ENV_PROJECT/node_modules"
    yarn
  end
  