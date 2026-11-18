# Official TON DNS source reference

Original project: https://github.com/ton-blockchain/dns-contract

The files in `func/` are vendored from the official repository and retained as an unmodified reference foundation. The original GPL-3.0 license is included at `LICENSE`.

Original project description:

- `nft-collection.fc` — DNS resolver and NFT collection/minter.
- `nft-item.fc` — domain NFT item; auction state and bidding logic are implemented in the item.
- `dns-utils.fc`, `op-codes.fc`, `params.fc`, and `stdlib.fc` — shared support code.

**Important:** these files implement TON DNS domain names, not Russian license plates. They are reference sources and must not be deployed as TagitalSpace contracts without adaptation. TagitalSpace-specific contracts will use the original TEP-62 NFT and auction patterns where appropriate, while implementing plate+region uniqueness, the TagitalSpace starting-price rules, annual renewal, and the agreed marketplace economics.

The original source files are preserved separately so that upstream code and its license notices remain traceable. Any derivative source must retain the GPL-3.0 terms and relevant upstream copyright notices, and must identify TagitalSpace modifications.
