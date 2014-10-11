# On Debian and Ubuntu

In Debian derived distributions, you can use the official Crystal repository.

## Setup repository

First you have to add the repository to your APT configuration. For easy setup just run in your command line:

```
  curl http://dist.crystal-lang.org/apt/setup.sh | sudo bash
```

That will add the signing key and the repository configuration. If you prefer to do it manually execute:

```
apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54
echo "deb http://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list
```

## Install
Once the repository is configured you're ready to install Crystal:

```
sudo apt-get install crystal
```

## Upgrade

When a new Crystal version is released you can upgrade your system using:

```
sudo apt-get update
sudo apt-get install crystal
```
