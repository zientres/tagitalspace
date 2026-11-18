# TON DNS Tolk reference modules

This directory contains the TON DNS/NFT reference implementation in Tolk, based on the official Tolk implementation in `ton-blockchain/acton-contracts/dns/contracts` and the original `ton-blockchain/dns-contract` FunC contracts.

Upstream sources:
- https://github.com/ton-blockchain/acton-contracts/tree/master/dns/contracts
- https://github.com/ton-blockchain/dns-contract

The original upstream license is GPL-3.0 and is retained at `../LICENSE`.

## Modules

- `DnsCollection.tolk`: collection deployment, blacklist check, NFT collection getters, DNS resolver.
- `DnsItem.tolk`: NFT item lifecycle, ownership transfer, DNS records, governance, release, getters.
- `auction.tolk`: bidding, outbid refunds, auction extension, ownership transfer.
- `dns-utils.tolk`: DNS parsing, validation, price schedule and timing constants.
- `messages.tolk`: opcodes and message layouts.
- `storage.tolk`: collection/item storage layouts, serialization and NFT data structures.
- `errors.tolk`: preserved error codes.

## TagitalSpace timing adaptation

The upstream DNS auction schedule is adapted for TagitalSpace:
- initial auction duration: 90 minutes (5,400 seconds);
- minimum remaining duration after a late bid: 60 minutes (3,600 seconds);
- an incoming bid extends the auction only when less than 60 minutes remain.

The reference DNS name-pricing schedule and domain validation remain upstream reference behavior. TagitalSpace plate pricing is implemented separately in `contracts/tolk/plate-pricing.tolk`.

## Migration notes

Tolk provides its own standard library and compiler built-ins, so FunC's `stdlib.fc` is not copied as a Tolk source file. Its functionality is supplied by Tolk/Acton primitives. FunC's separate `params.fc`, `op-codes.fc`, and DNS utility definitions are represented in `dns-utils.tolk`, `messages.tolk`, and `errors.tolk`.

The legacy FunC directory is intentionally retained as a comparison source until the Tolk port is compiled, tested against the original behavior, and integrated into the project's Acton build. These files are reference material and must not be deployed.
