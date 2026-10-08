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
  - One SSID per VLAN, with main able to reach IoT and guests but not the reverse
  - VqLANs for isolation inside a single VLAN
  - Device Active Protect, with quarantine for new devices
planned:
  - Why isolate IoT devices and guests at all
  - VLANs on Firewalla
  - VqLAN, and when layer 2 ACLs beat a VLAN
  - What broke along the way
---

I'm using Firewalla gear (a Gold Pro and an AP7) to split my home network into isolated segments, in layers: a VLAN per SSID, VqLANs inside a VLAN, and device-level isolation on top. The goal is real isolation without enterprise hardware, and without losing a weekend to switch configs or fixing something I broke while editing them.

Why: IoT devices and guests are the least trustworthy things on my network, and IoT devices are, generally, inherently insecure. I don't want either one to have a path to the machines I care about, like my NAS.

## Further reading

- [Gamers Nexus on LG smart TVs](https://youtu.be/6IFVTcM28KA?t=822): "we own the glass", and voice-to-text [saving transcripts to memory](https://youtu.be/6IFVTcM28KA?t=2780) at 46:20.
- [Know who's in your LG household](https://tech.yahoo.com/cybersecurity/articles/know-whos-lg-household-own-134138391.html) (Yahoo Tech): the "we own the glass" pitch to advertisers, and LG's response.
- [LG smart TV audio logging](https://urbanwired.com/lg-smart-tv-audio-logging/) (Urban Wired): the TV cataloguing devices on your network.
- [LG smart TVs record with the screen off and scan your whole home network](https://tech-ish.com/2026/09/09/lg-smart-tvs-record-with-the-screen-off-and-scan-your-whole-home-network/) (Tech-ish): the webOS exploit and the standby behavior.
