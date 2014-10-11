# On RedHat and CentOS

In RedHat derived distributions, you can use the official Crystal repository.

## Setup repository

First you have to add the repository to your YUM configuration. For easy setup just run in your command line:

```
  curl http://dist.crystal-lang.org/rpm/setup.sh | sudo bash
```

That will add the signing key and the repository configuration. If you prefer to do it manually execute:

```
rpm --import http://dist.crystal-lang.org/rpm/RPM-GPG-KEY

cat > /etc/yum.repos.d/crystal.repo <<END
[crystal]
name = Crystal
baseurl = http://dist.crystal-lang.org/rpm/
END
```

## Install
Once the repository is configured you're ready to install Crystal:

```
sudo yum install crystal
```

## Upgrade

When a new Crystal version is released you can upgrade your system using:

```
sudo yum update crystal
```
