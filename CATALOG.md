
This file serves as a catalog of high level metadata of machines that are not managed by NixOS. For the NixOS managed macnines see "Host info" in nixos/<hostname>/default.nix


# Prompt for network diagram

If asked to generate a network diagram follow these instructions. Read this file for info on each host. Then generate a network diagram representing them. 

This should include seperation between networks. Almost everything is in tailscale, so you dont need to explicitly need to draw links for every mesh link. Maybe just encapsulate those in a 'tailnet' box. Everything is in tailnet unless otherwise specified here in this doc.

Since most hosts have NixOS configs, you can get more info about them by reading the config for each one at 'nixos/<hostname>/default.nix'. For example in there you will find what services they are running and what syncthing devices they are connected to (but dont graph synchthing for now). Not every service needs to show up on the diagram. But if you can pick a good icon for each host that would be good. Like ones that differentiate a raspberry pi, from a workstation, from a router.

On the graph it should show the generation date.

Generate graph with mermaid, or python diagrams (https://diagrams.mingrammer.com/docs/getting-started/examples)


# Hosts


## Orc

description: cloud server for external services like sync and uptime monitoring
hardware: ARM server
software: NixOS
network: oracle


## BerkNAS

type: NAS
network: berk (but cant run tailscale, so its being exposed via tailscale subnet router by Matcha)


## Matcha

description: offsite backup
hardware: minipc x86 N100
software: NixOS
network: berk


## Lute    -  TODO

## Dobro

description: main work station running ZFS, backups to nas and offsite
hardware: Desktop home build workstation
software: NixOS
network: home
specs: 
	Intel® Core™ i7-6700K × 8
	motherboard: MSI MS-7972
	nixos, 64gb memory
	1tb root ssd, 2tb rust datadrive


## Nas

type: NAS
network: home (but not tailscale)


## Zeeba

description: server for backups, sync, web, samba
type: server
hardware: xeon 1U blade
software: NixOS
network: home
specs: 
	SUPERMICRO MBD-X9SCL-F-O LGA 1155 Intel C202 Micro ATX Intel Xeon E3
 	Intel(R) Xeon(R) CPU E3-1220 V2 @ 3.10GHz (4 cores, 4 threads)
 	32gb mem max, filled out
 	1tb ssd
 	60gb swap M2
 	5Tb zfs


## Opnsense

type: router
hardware: minipc x86
software: Opnsense
network: home
description: main gateway for home network

specs: AOOSTAR opnsense, $189
	AOOSTAR N-BOX Pro Intel N100 Mini PC With LPDDR5 16G RAM
	M.2 SSD W11 PRO 2.5G LAN Full-featured Type-C Port - 16GB RAM +512G...
	dual nics


## Choco

network: lemon
type: Arch linux running on Raspberry PI
description: server for offsite backup and sync

specs: raspberry pi 3 b
	Hardware	: BCM2835
	Revision	: a02082
	Serial		: 00000000393d6db4
	Model		: Raspberry Pi 3 Model B Rev 1.2


## x200

description: personal laptop
hardware: Thinkpad x200
software: NixOS
network: roaming
specs: 12" screen, 4gb ram, core 2 duo


## Nixahi

description: personal laptop
hardware: Apple M1
software: NixOS Asahi
network: roaming
specs: 16gb mem, 1tb storage


## impb

description: personal laptop
hardware: Apple i5
software: NixOS
network: roaming


## jonodot

description: work laptop
hardware: Apple M4
software: OSX
network: roaming


## Galaxy S23

type: phone
hardware: Samsung Galaxy S23
network: roaming


## Plex

status: offline, not plugged in
type: router
hardware: micro desktop tower
software: NixOS
description: backup router which can be swapped out with opnsense machine for testing
specs: dell optiplex 9010
	Intel(R) Core(TM) i5-3470S CPU @ 2.90GHz, 16gb mem. 32gb max

