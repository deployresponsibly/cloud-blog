---
title: Home network
question: How do you keep invasive IoT devices and guests off your main network without running enterprise gear?
summary: How I use Firewalla to carve my home network into VLANs and VqLANs, so IoT devices and guests can't see the machines I care about.
status: in-progress
started: 2026-10-04
stack: [Firewalla Gold Pro, Firewalla AP7, VLAN, VqLAN]
architecture:
  caption: One Firewalla Gold Pro routes everything, and one AP7 broadcasts an SSID per VLAN. Main can reach IoT and guests, but not the other way around.
  zones:
    - { id: firewalla, label: Firewalla }
    - { id: segments, label: One SSID per VLAN }
  nodes:
    - { id: internet, label: Internet, col: 1, row: 2, accent: true }
    - { id: gold, label: Gold Pro, col: 2, row: 2, zone: firewalla }
    - { id: ap7, label: AP7, col: 3, row: 2, zone: firewalla }
    - { id: main, label: Main VLAN, col: 4, row: 1, zone: segments }
    - { id: iot, label: IoT VLAN, col: 4, row: 2, zone: segments }
    - { id: guest, label: Guest VLAN, col: 4, row: 3, zone: segments }
  edges:
    - { from: internet, to: gold, both: true }
    - { from: gold, to: ap7, label: trunk }
    - { from: ap7, to: main }
    - { from: ap7, to: iot }
    - { from: ap7, to: guest }
detail:
  caption: Zoomed in on the IoT VLAN. Main can reach in, but IoT can't reach back. VqLANs keep unrelated IoT devices from talking to each other, and new devices are quarantined until I approve them. Device Active Protect runs on the Gold Pro.
  zones:
    - { id: vqlan, label: IoT VLAN with VqLANs, blocked: true }
    - { id: quarantine, label: IoT VLAN Quarantine, blocked: true }
  nodes:
    - { id: main, label: Main VLAN, col: 1, row: 2, accent: true }
    - { id: gold, label: Gold Pro + DAP, col: 2, row: 2 }
    - { id: tv, label: Smart TV, col: 3, row: 1, zone: vqlan }
    - { id: thermo, label: Thermostat, col: 3, row: 2, zone: vqlan }
    - { id: cam, label: Camera, col: 3, row: 3, zone: vqlan }
    - { id: newdev, label: New device, col: 3, row: 4, zone: quarantine }
  edges:
    - { from: main, to: gold, label: allowed }
    - { from: gold, to: tv }
    - { from: gold, to: thermo }
    - { from: gold, to: cam }
    - { from: tv, to: thermo, label: blocked, dashed: true, both: true }
    - { from: thermo, to: cam, label: blocked, dashed: true, both: true }
decisions:
  - Mapped one SSID to one VLAN for base isolation, with rules that block IoT and guest traffic to the main network while main can still reach them.
  - Used VqLANs for isolation inside a single VLAN, so unrelated devices on the same network can't talk to each other either.
  - Turned on device-level isolation with Device Active Protect, with device quarantine enabled.
  - This enables a multi-layered defense against what I consider malicious IoT devices that I choose to have in my house.
planned:
  - Why isolate IoT devices and guests at all
  - VLANs on Firewalla
  - VqLAN, and when layer 2 ACLs beat a VLAN
  - What broke along the way
---
