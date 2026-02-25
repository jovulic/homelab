# flint

The configuration for flint is manual and involves logging into the admin portal and performing a number of configuration changes.

## Setup: System

The follow applies to configuration found under the "System" tab.

1. Change hostname to `flint`.
2. Change timezone to `UTC`.
3. Add my SSH key and disable password based authentication for SSH.
4. Enable HTTPS (redirect to HTTPS via "HTTP(S) Access").

## Setup: Network

The following applies to configuration found under the "Network" tab.

1. Update `lan` interface...
   1. Set IPv4 address to `192.168.1.1`.
2. Disable guest wireless interfaces.
3. Update `wifi0` interface...
   1. Set SSID to `.`.
   2. Set encryption to `WPA2-PSK`.
   3. Set key.
   4. Set country.
4. Update `wifi1` interface...
   1. Set SSID to `.`.
   2. Set encryption to `WPA2-PSK`.
   3. Set key.
   4. Set country.
5. Update `wifi2` interface...
   1. Set SSID to `.`.
   2. Set encryption to `WPA2-PSK`.
   3. Set key.
   4. Set country.
6. Configure DNS for static addresses...
   1. Add hostname mapping `terra.lan` to `192.168.1.5`.
   2. Add hostname mapping `frost.lan` to `192.168.1.10`.
