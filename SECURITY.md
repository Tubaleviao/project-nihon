# Security policy

Project Nihon is a multiplayer game whose host is authoritative. The most serious bugs are the ones
that let a client make the host do something it should not: crash it, exhaust its memory or
bandwidth, read or change another player's data, or skip a rule the host should enforce.

## Reporting a vulnerability

Report it privately. Do not open a public issue or pull request, and do not post it in a community
channel, until a fix is released.

1. Use GitHub's private reporting: the **Security** tab of this repository, then **Report a
   vulnerability** (a private security advisory).
2. If that is not available to you, email the maintainer at the address on the repository owner's
   GitHub profile with "Project Nihon security" in the subject.

Include the version or commit, the boot role (host, dedicated server or client), the steps or
packets needed to reproduce it, and what it lets an attacker do. A script or capture helps.

## What to expect

- An acknowledgement within 7 days.
- A fix or a written assessment within 30 days for a confirmed issue, sooner for one that is being
  exploited.
- Credit in the release notes if you want it.

## Scope

In scope: the host and dedicated server (network input handling, authority checks, rate limits,
persistence), the client's handling of data from a host, and the build and release workflows.

Out of scope: the private `assets-prod/` submodule's art, denial of service by raw network
flooding that no application-level code could resist, and issues that need the attacker to
already control the host machine.

## Supported versions

Only the latest release and `main` receive fixes. There is no stable branch before `v0.1.0`.
