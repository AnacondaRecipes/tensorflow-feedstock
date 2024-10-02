Recipes for Tensorflow related conda packages for tensorflow >1.8.0,<=2.12 can be found at:
https://github.com/AnacondaRecipes/tensorflow_recipes

We are moving back to using this feedstock as of tensorflow 2.17.0.

This isn't a fork of conda-forge's feedstock. Whoever works on this and wishes to bring changes from the conda-forge feedstock should pull conda-forge's changes and reapply changes made in this PR on top of that.

To build a conda TensorFlow package with or without GPU support you can use
docker and the `build-locally.py` script.

1. Install docker. Ensure that the following command succeeds:

```bash
docker run hello-world
```

2. Build a specific version with the command
```bash
python build-locally.py
```

3. Generally speaking, this package takes too long to compile on any of our CI
   resources. One should follow CFEP-03 to package this feedstock.

The following script may help build all cuda version sequentially:
```bash
#!/usr/env/bin bash

set -ex

docker system prune --force
configs=$(find .ci_support/ -type f -name 'linux_64_*' -printf "%p ")

# Assuming a powerful enough machine with many cores
# 10 seems to be a good point where things don't run out of RAM too much.
export CPU_COUNT=10

mkdir -p build_artifacts

for config_filename in $configs; do
    filename=$(basename ${config_filename})
    config=${filename%.*}
    if [ -f build_artifacts/conda-forge-build-done-${config} ]; then
        echo skipped $config
        continue
    fi

    python build-locally.py $config | tee build_artifacts/${config}-log.txt

    if [ ! -f build_artifacts/conda-forge-build-done-${config} ]; then
        echo "it seems there was a build failure. I'm going to stop now."
        echo The failure seems to have originated from
        echo ${config}
        exit 1
    fi
    # docker images get quite big clean them up after each build to save your disk....
    docker system prune --force
done

zip build_artifacts/log_files.zip build_artifacts/*-log.txt
```
