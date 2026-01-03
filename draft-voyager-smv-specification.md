---
title: Secure Mobile Vault Format
abbrev: SMVF
docname: draft-voyager-smv-specification-latest
category: info

ipr: trust200902
area: General
keyword: Internet-Draft

stand_alone: yes
smart_quotes: no
pi: [toc, sortrefs, symrefs]

author:
  -
    name: Ohto Keskilammi
    email: voyager-2019@outlook.com
    organization: Self-published

normative:
  RFC2119:   # Boilerplate
  RFC4106:   # AES-GCM
  RFC8439:   # ChaCha20-Poly1305
  RFC9106:   # Argon2
  RFC7914:   # scrypt
  RFC3339:   # Timestamps (instead of ISO 8601)

informative:
  RFC9562:   # UUID format
  RFC8259:   # JSON standard

date: 2026-01-03

--- abstract

The Secure Mobile Vault Format (SMVF) defines a binary container format for storing encrypted password vaults on mobile devices. The format is designed to be offline-first, zero-knowledge, cryptographically robust, and forward-compatible. SMVF specifies strict structural layout, authenticated encryption, and deterministic metadata handling suitable for constrained mobile environments.

--- middle

# Status of This Memo

This Internet-Draft is submitted in full conformance with the
provisions of BCP 78 and BCP 79.

Internet-Drafts are working documents of the Internet Engineering
Task Force (IETF).  Note that other groups may also distribute
working documents as Internet-Drafts.

Internet-Drafts are draft documents valid for a maximum of six months
and may be updated, replaced, or obsoleted by other documents at any
time.  It is inappropriate to use Internet-Drafts as reference
material or to cite them other than as "work in progress".

# Copyright Notice

Copyright (c) 2026 IETF Trust and the persons identified as the
document authors.  All rights reserved.

This document is subject to BCP 78 and the IETF Trust's Legal
Provisions Relating to IETF Documents.

# Introduction

The Secure Mobile Vault Format (SMVF) defines a binary container format for storing encrypted password vaults on mobile devices. The format is designed to be offline-first, zero-knowledge, cryptographically robust, and forward-compatible.

SMVF follows strict principles including explicit headers, typed sections, cryptographic framing, and strict versioning, while remaining minimal and suitable for mobile environments.

# Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL
      NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",  "MAY", and
      "OPTIONAL" in this document are to be interpreted as described in
      [RFC2119].

# Design Goals

The format is designed to meet the following goals:

1. Provide zero-knowledge encryption where vault contents cannot be recovered without the master password.
2. Support offline-only operation with no network dependencies.
3. Be safe for mobile storage, including crash-safe atomic updates.
4. Use authenticated encryption to ensure confidentiality and integrity.
5. Allow future evolution without breaking existing vaults.
6. Remain auditable and deterministic in layout.

# File Overview

An SMVF file consists of the following components, in order:

* File Header (fixed-size)
* KDF Parameters Section
* Crypto Parameters Section
* Encrypted Vault Section
* Optional Footer

All multi-octet integer fields are encoded in network byte order (big-endian). The file is tightly packed and contains no padding.

The standard file extension is ".smvf".

# File Header

The file header is a fixed-size structure of 32 octets.

The header contains the following fields:

* Magic (4 octets)
  Identifies the file as an SMVF container. The value MUST be the ASCII string "SMVF".

* Major Version (2 octets)
  Indicates the major format version. Readers MUST reject files with unsupported major versions.

* Minor Version (2 octets)
  Indicates backward-compatible revisions.

* Header Length (4 octets)
  Total length in octets of all sections except the Encrypted Vault Section length preceding the encrypted payload.

* Flags (4 octets)
  Bitmask defining file properties.

* File UUID (16 octets)
  Randomly generated UUID version 4 identifier as defined in [RFC9562]. This value is non-secret and MUST NOT be reused.

The following header flags are defined:

* Bit 0: Encrypted payload present (MUST be set)
* Bit 1: Footer present
* Bits 2-31: Reserved and MUST be zero

# Section Model
{: #sec-model }

Sections follow a typed-length-value (TLV) model.

Each section consists of:

* Section Type (2 octets)
* Section Length (4 octets)
* Section Value (variable length)

The section length specifies the length of the section value only.

Unknown section types MUST be skipped using the length field. The section order defined in this specification MUST be preserved.

# Section Types
{: #sec-types }

The following section types are defined:

* 0x0001: KDF Parameters Section (REQUIRED)
* 0x0002: Crypto Parameters Section (REQUIRED)
* 0x0003: Encrypted Vault Section (REQUIRED)
* 0x0004-0x7FFF: Reserved for future use and MUST NOT be used

No section identifier may be reused for a different purpose.

# KDF Parameters Section

This section defines how the encryption key is derived from the master password.

The section value contains the following fields:

* KDF Algorithm (1 octet)
* Salt Length (1 octet)
* Salt (variable length)
* Cost Parameter A (4 octets)
* Cost Parameter B (4 octets)
* Cost Parameter C (4 octets)

The following KDF Algorithm identifiers are defined:

* 0x01: Argon2id as defined in [RFC9106]
* 0x02: scrypt as defined in [RFC7914]
* 0x03-0x7F: Reserved for future use and MUST NOT be used

The salt is not secret and MUST be generated randomly per vault.

For Argon2id, the parameters are defined as follows:

* Parameter A: Memory cost in KiB
* Parameter B: Iteration count
* Parameter C: Degree of parallelism

For scrypt, the parameters are defined as follows:

* Parameter A: N (CPU/memory cost)
* Parameter B: r
* Parameter C: p

Implementations SHOULD tune parameters for mobile hardware while maintaining resistance to offline attacks.

# Crypto Parameters Section

This section defines the encryption algorithm and parameters used to protect the vault payload.

The section value contains the following fields:

* Cipher Algorithm (1 octet)
* Key Length (1 octet)
* Nonce Length (1 octet)
* Authentication Tag Length (1 octet)
* Nonce (variable length)

The following Cipher Algorithm identifiers are defined:

* 0x01: AES-256-GCM as defined in [RFC4106]
* 0x02: ChaCha20-Poly1305 as defined in [RFC8439]
* 0x03-0x7F: Reserved for future use and MUST NOT be used

For AES-256-GCM and ChaCha20-Poly1305, the Key Length MUST be 32 octets.

Implementations MUST ensure that a nonce is never reused with the same derived key. The authentication tag is embedded in the AEAD ciphertext and is not stored separately.

# Encrypted Vault Section

This section contains the encrypted vault payload.

The payload is produced using an AEAD construction with the following inputs:

* The encryption key is derived from the master password using the KDF Parameters Section.
* The nonce is taken from the Crypto Parameters Section.
* The additional authenticated data consists of the File Header, the KDF Parameters Section, and the Crypto Parameters Section.

All metadata is authenticated but not encrypted. Any modification to these components MUST cause decryption failure.

The AAD input MUST be the exact serialized octet sequence of the File Header followed by the serialized KDF Parameters Section and the serialized Crypto Parameters Section, in file order.

# Vault Payload Structure

Before encryption, the vault payload is serialized JSON as defined in [RFC8259]. All JSON strings MUST be encoded in UTF-8.

No canonicalization of the JSON payload is required, as integrity is provided by the enclosing AEAD construction.

The top-level object contains the following fields:

* vault_version: Integer indicating the logical vault schema version
* created: [RFC3339] timestamp
* updated: [RFC3339] timestamp
* entries: Array of vault entries
* metadata: Optional application-defined metadata

# Vault Entry Structure

Each vault entry is a [RFC8259] JSON object containing the following fields:

* id: UUID version 4 string as defined in [RFC9562]
* type: Entry type identifier
* title: Human-readable name
* fields: Key-value mapping of entry fields
* notes: Optional freeform text
* tags: Optional array of strings
* created: [RFC3339] timestamp
* updated: [RFC3339] timestamp

The type field allows future extension to support non-password secrets.

# Authentication and Integrity

The format relies exclusively on AEAD for security guarantees.

The following properties are provided:

* Confidentiality of vault contents
* Integrity of vault contents
* Integrity and authenticity of metadata

No separate MAC or digital signature is required.

# Atomic Update Requirements

Implementations MUST perform updates atomically to prevent vault corruption.

A recommended procedure is as follows:

1. Write the updated vault to a temporary file.
2. Flush and synchronize the file.
3. Atomically rename the temporary file over the existing vault.
4. Optionally retain a backup copy.

Mobile operating systems guarantee atomic rename operations within the same filesystem.

# Memory Handling Requirements

Implementations MUST enforce the following requirements:

* Derived encryption keys MUST NOT be persisted.
* Keys MUST be zeroized on lock or application backgrounding.
* Decrypted vault data MUST reside only in memory and MUST be discarded on lock or suspension.

# Forward Compatibility Rules

Readers MUST reject files with unsupported major versions.

Readers MUST ignore unknown section types.

Writers MUST preserve section ordering and MUST NOT reuse section identifiers.

# Explicit Non-Goals

The format intentionally excludes:

* Cloud synchronization
* Compression
* Partial encryption
* Password reuse detection
* Replay protection

# Threat Model Summary

The format mitigates:

* Offline file theft
* Unauthorized modification
* Metadata tampering

The format does not mitigate:

* Compromised or rooted operating systems
* Active runtime memory attacks
* Screen capture malware

# IANA Considerations

This document has no IANA actions.

# Security Considerations

This document specifies a cryptographic container format intended to protect sensitive data at rest. Security properties and assumptions are discussed throughout the document, including key derivation, authenticated encryption, and memory handling requirements.

The format assumes a trusted execution environment and does not protect against compromised operating systems, runtime memory disclosure, or malicious software with sufficient privileges. Implementers are responsible for selecting appropriate cryptographic parameters and ensuring correct use of underlying cryptographic primitives.

--- back

# Acknowledgments
{:numbered="false"}

# Authors' Addresses
{:numbered="false"}

Ohto Keskilammi
Email: voyager-2019@outlook.com
