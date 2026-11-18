# TagitalSpace TON contracts

This directory contains the on-chain implementation for TagitalSpace. All deployments and tests must target TON Testnet (network id `-3`) until explicitly changed.

## Plate starting-price rules

The initial auction bid is calculated by `contracts/tolk/plate-pricing.tolk`. The six-character body is used; the region code is not part of this calculation.

| Feature | Amount |
|---|---:|
| No special pattern | 3 TON |
| Mirrored letters (ABA, where A != B) | 15 TON |
| Mirrored digits (121, where 1 != 2) | 15 TON |
| Three identical letters (AAA) | 50 TON |
| Three identical digits (777) | 50 TON |

If both letter and digit patterns apply, their amounts are added. The 3 TON base amount is used only when neither pattern applies. A triple identical pattern is counted once as 50 TON, not as 50 + 15 TON.

Expected examples:
- `A777AA` (А777АА): 100 TON.
- `A616AA` (А616АА): 65 TON.
- `A888OA` (А888ОА): 65 TON.
- `M343YM` (М343УМ): 30 TON.
- An ordinary pattern: 3 TON.

The FunC helper accepts exactly six canonical ASCII characters. The Russian allowed letters are transliterated to their visually corresponding Latin characters: А→A, В→B, Е→E, К→K, М→M, Н→H, О→O, Р→P, С→C, Т→T, У→Y, Х→X. The region is stored and checked separately by the registry/collection contract.

## Source attribution and license

The DNS/NFT Tolk reference modules are now present in `contracts/vendor/ton-dns/tolk/`, based on the official `ton-blockchain/acton-contracts` Tolk DNS implementation and the original `ton-blockchain/dns-contract` project. The original GPL-3.0 license is retained at `contracts/vendor/ton-dns/LICENSE`. TagitalSpace-specific changes and auction timing adaptations are documented in the vendor Tolk README. Do not remove upstream attribution or license notices.

## Auction timing

TagitalSpace follows the current TON DNS auction timing: the initial auction duration is one hour (3,600 seconds).

When a valid bid arrives with less than one hour remaining, the auction end time is moved to `now + 3,600` seconds, leaving a full hour after that bid. A bid with exactly one hour or more remaining does not extend the auction.

The reusable Tolk timing helper is `contracts/tolk/auction-timing.tolk`; boundary and extension cases are listed in `contracts/tests/auction-timing-vectors.json`. These JSON vectors are specifications for the test suite, not evidence that the Tolk helper has already been compiled or executed.

## Tolk migration status

New TagitalSpace-specific helpers are being ported to Tolk under `contracts/tolk/`. The upstream TON DNS FunC sources are retained temporarily as the migration reference and must not be deployed. The Tolk reference collection and item contracts, utility modules, opcodes/message layouts, error codes, and storage layouts have been added. Tolk stdlib functionality is supplied by the language/runtime rather than by a copied FunC stdlib file. The migration is not complete until these files are compiled, tested against the original behavior, integrated into the Acton build, and the remaining project-specific contracts and tests are migrated. The upstream GPL-3.0 license and required notices must remain available.
