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

1. Configure `lan` interface...
   1. Set IPv4 address to `192.168.1.1`.
2. Disable guest wireless interfaces.
3. Configure `wifi0` interface...
   1. Set SSID to `.`.
   2. Set encryption to `WPA2-PSK`.
   3. Set key.
   4. Set country.
4. Configure `wifi1` interface...
   1. Set SSID to `.`.
   2. Set encryption to `WPA2-PSK`.
   3. Set key.
   4. Set country.
5. Configure `wifi2` interface...
   1. Set SSID to `.`.
   2. Set encryption to `WPA2-PSK`.
   3. Set key.
   4. Set country.
6. Configure DNS for static addresses...
   1. Add hostname mapping `terra.lan` to `192.168.1.5`.
   2. Add hostname mapping `frost.lan` to `192.168.1.10`.
   3. Add hostname mapping `phantom.lan` to `192.168.1.11`.
   4. Add hostname mapping `hades.lan` to `192.168.1.12`.
   5. Add hostname mapping `optiplex.lan` to `192.168.1.13`.
   6. Add hostname mapping `think1.lan` to `192.168.1.14`.
   7. Add hostname mapping `think2.lan` to `192.168.1.15`.
   8. Add hostname mapping `think3.lan` to `192.168.1.16`.
7. Configure DNS forwardings for `.lab` to DNS server on `terra` (`/*.lab/192.168.1.5`).

## Setup: VPN

The following are the steps to follow to setup a VPN server and have it work on
the network. The approach here makes use of NAT to both handle the different
subnet constraint and also keep it localized to the router.

Terms to keep in mind:

- NAT: Address to address mapping.
- NETMAP (1:1 NAT): Using custom rules to easily do a 1:1 mapping between address and address.
- SNAT: Using "masquerading" which is where the source of the packet get overwritten with the router's IP.
- DNAT: The opposite of SNAT where we are overwriting the destination IP.

Perform the following steps to setup the VPN.

1. Via GL.iNet configure VPN WireGuard Server...
   1. Enable the WireGuard Sever.
   2. Under Options set `Allow Remote Access to the LAN Subnet`.
      _Once the server is started (will run on `10.0.0.1`) this will handle the masquerading (see `wgserver` zone) and forwarding to lan (via rules) -- no zone changes required._
2. Via LuCI configure `lan` interface.
   1. Go to General Settings and add a new IPv4 address of `10.10.10.1/24`.
      _Now the router is listening on both `192.168.1.1` and `10.10.10.1`._
3. Via LuCI manually configure port forwarding rules like so...
   ```
   Name: vpn to frost.lan
   Protocol: TCP+UDP
   Source zone: wgserver
   External IP address: 10.10.10.10
   External port: 1-65535
   Internal zone: lan
   Internal IP address: 192.168.1.10
   Internal port: (BLANK)
   ```
4. Via SSH configure mapping (NETMAP). **NEVERMIND this does not work, but keeping around as it is technically interesting.**
   1. Create the file `/etc/nftables.d/10-vpn-netmap.nft` with the following contents...
      ```
      chain dstnat {
          ip daddr 10.10.10.0/24 dnat ip prefix to 192.168.1.0/24 comment "1:1 NAT VPN to Homelab"
      }
      ```
      _Tells the router that any packet destined for a `10.10.10.X` address should have its network prefix rewritten to `192.168.1.X`, keeping the host ID exactly the same._
      **Or the following as the above did not work (likely given older kernel).**
      ```
      chain dstnat {
          ip daddr 10.10.10.0/24 dnat to ip daddr & 0.0.0.255 | 192.168.1.0 comment "1:1 NAT VPN to Homelab"
      }
      ```
      _Uses a subnet mask (0.0.0.255) to strip away the 10.10.10 part of the IP, leaving just the .5. It then adds 192.168.1.0 to it, resulting in 192.168.1.5._
   2. Reload the configuration with `fw4 reload`.
   3. Verify the configuration with `nft list ruleset | grep 10.10.10.0` and `fw4 print | grep 10.10.10.0`.

Also, some useful commands related to wireguard to be run on flint.

- `wg show` - Output current wireguard server configuration and list of all configured peers along with their last handshake.
