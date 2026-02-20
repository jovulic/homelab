# bootstrap

_The bootstrap for hosts._

## Description

The configuration here defines the what would be loaded into a "boostrap USB". The purpose of this USB is to reprovision the machine back to a "base configuration" where it then is to be configured remotely.

The state of this base configuration is a minimal machine with open SSH ports and authorized SSH users.

It works by describing a service that will run a script on startup that performs a number of steps to provision the machine. It is expected that this is packaged into a installer iso image.
