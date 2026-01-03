---
title: Secure Mobile Vault Format (SMVF)
abbrev: SMVF
docname: draft-voyager-svm-specification-latest
category: info

ipr: trust200902
area: General
workgroup: smv
keyword: Internet-Draft

stand_alone: yes
smart_quotes: no
pi: [toc, sortrefs, symrefs]

author:
  -
    name: Ohto Keskilammi
    organization: smv
    email: voyager-2019@outlook.com

normative:
  RFC2119:

informative:

--- abstract

The Secure Mobile Vault Format (SMVF) defines a binary container format for storing encrypted password vaults on mobile devices. The format is designed to be offline-first, zero-knowledge, cryptographically robust, and forward-compatible. SMVF specifies strict structural layout, authenticated encryption, and deterministic metadata handling suitable for constrained mobile environments.

--- middle

# Introduction

The Secure Mobile Vault Format (SMVF) defines a binary container format for storing encrypted password vaults on mobile devices. The format is designed to be offline-first, zero-knowledge, cryptographically robust, and forward-compatible.

SMVF follows ZXTX-style principles including explicit headers, typed sections, cryptographic framing, and strict versioning, while remaining minimal and suitable for mobile environments.

The key words MUST, MUST NOT, REQUIRED, SHOULD, SHOULD NOT, and MAY in this document are to be interpreted as described in RFC 2119.

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
  Total length in octets of the header plus all mandatory sections preceding the encrypted payload.

* Flags (4 octets)
  Bitmask defining file properties.

* File UUID (16 octets)
  Randomly generated unique identifier. This value is non-secret and MUST NOT be reused.

The following header flags are defined:

* Bit 0: Encrypted payload present (MUST be set)
* Bit 1: Footer present
* Bits 2–31: Reserved and MUST be zero

# Section Model
{: #sec-model }

Sections follow a typed-length-value (TLV) model.

Each section consists of:

* Section Type (2 octets)
* Section Length (4 octets)
* Section Value (variable length)

The section length specifies the length of the section value only.

Unknown section types MUST be skipped using the length field. The section order defined in this specification MUST be preserved for version 1.0.

# Section Types
{: #sec-types }

The following section types are defined:

* 0x01: KDF Parameters Section (REQUIRED)
* 0x02: Crypto Parameters Section (REQUIRED)
* 0x03: Encrypted Vault Section (REQUIRED)
* 0x7F: Reserved for future use

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

* 0x01: Argon2id
* 0x02: scrypt

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

* 0x01: AES-256-GCM
* 0x02: ChaCha20-Poly1305

The nonce MUST be generated randomly per vault file. The authentication tag is embedded in the AEAD ciphertext and is not stored separately.

# Encrypted Vault Section

This section contains the encrypted vault payload.

The payload is produced using an AEAD construction with the following inputs:

* The encryption key is derived from the master password using the KDF Parameters Section.
* The nonce is taken from the Crypto Parameters Section.
* The additional authenticated data consists of the File Header, the KDF Parameters Section, and the Crypto Parameters Section.

All metadata is authenticated but not encrypted. Any modification to these components MUST cause decryption failure.

# Vault Payload Structure

Before encryption, the vault payload is serialized as UTF-8 encoded JSON.

The top-level object contains the following fields:

* vault_version: Integer indicating the logical vault schema version
* created: ISO 8601 UTC timestamp
* updated: ISO 8601 UTC timestamp
* entries: Array of vault entries
* metadata: Optional application-defined metadata

# Vault Entry Structure

Each vault entry is a JSON object containing the following fields:

* id: UUID version 4 string
* type: Entry type identifier
* title: Human-readable name
* fields: Key-value mapping of entry fields
* notes: Optional freeform text
* tags: Optional array of strings
* created: ISO 8601 UTC timestamp
* updated: ISO 8601 UTC timestamp

The type field allows future extension to support non-password secrets.

# Authentication and Integrity

The format relies exclusively on AEAD for security guarantees.

The following properties are provided:

* Confidentiality of vault contents
* Integrity of vault contents
* Integrity and authenticity of metadata

No separate MAC or digital signature is required in version 1.0.

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

# Rationale and ZXTX Lineage

SMVF adopts ZXTX-style design principles including structured sections, explicit cryptographic framing, metadata authentication, and specification-first development.

The format simplifies ZXTX concepts to better suit mobile constraints and usability requirements.

# References

## Normative References

[RFC2119] Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", BCP 14, RFC 2119.

## Informative References


--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
