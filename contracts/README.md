# TagitalSpace TON contracts

All deployments and tests must target TON Testnet (network id -3) until explicitly changed.

## Architecture

TagitalSpace follows the TON DNS collection/item model:
- TagitalSpaceRegistry.tolk validates a plate and region, derives the deterministic item StateInit and deploys the per-plate item with the first bid.
- PlateItem.tolk is the individual NFT/auction contract. Every plate has its own contract and local auction state.
- plate-item-auction.tolk implements bids, outbid refunds, deadline extension and settlement.
- There is no Auction Manager or shared auction-state contract.

The per-item contract is based on the upstream TON DNS Tolk DnsItem.tolk and auction.tolk patterns. Upstream attribution and GPL-3.0 license are retained under contracts/vendor/ton-dns/.

## Plate starting-price rules

The initial bid is calculated from the six-character body only; region does not affect price.

| Feature | Amount |
|---|---:|
| No special pattern | 3 TON |
| Mirrored letters | 15 TON |
| Mirrored digits | 15 TON |
| Three identical letters | 50 TON |
| Three identical digits | 50 TON |

If both letter and digit patterns apply, their amounts are added. Base 3 TON applies only when neither pattern applies. A triple is counted once as 50 TON, not 50 + 15 TON.

Examples: A777AA = 100 TON; A616AA = 65 TON; A888OA = 65 TON; M343YM = 30 TON; ordinary = 3 TON.

Allowed canonical ASCII letters: ABEKMHOPCTYX. Cyrillic input is transliterated by the client. Russia region allowlist is in russia-regions.tolk; region 20 is excluded.

## Auction rules

- First bid starts the item's one-hour auction.
- Every later bid is at least floor(current bid × 105 / 100).
- A bid with less than one hour remaining resets the deadline to one hour from the bid; exactly one hour remaining does not extend.
- No bid history is stored.
- Winning proceeds are split 50% collection owner, 30% Registry treasury, 20% development/security fund.

## Implementation status

The Registry-to-item deployment path and the first per-item auction implementation are in progress. The current source has not yet passed Tolk compilation, TVM tests, payout-bounce tests or a Testnet end-to-end run. In particular, bounce-safe refund/payout liabilities, treasury withdrawal, NFT transfer and annual renewal must be completed before deployment.

## Source attribution

The DNS/NFT Tolk reference modules are based on the official ton-blockchain/acton-contracts Tolk DNS implementation and the original ton-blockchain/dns-contract project. The upstream GPL-3.0 license is retained at contracts/vendor/ton-dns/LICENSE. Do not remove upstream attribution or license notices.
