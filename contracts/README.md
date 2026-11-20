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

- First bid starts the item's one-hour auction. The bid amount is encoded separately from attached TON: the opening transaction must attach the starting price plus 0.15 TON for item reserve and deployment/forwarding costs; the item records only the calculated starting price as the bid.
- Later bid messages include an explicit `bidAmount`; any additional attached TON remains as contract reserve and is not counted as part of the bid.
- Every later bid is at least floor(current bid × 105 / 100) and attaches at least 0.05 TON above the bid amount as a refund/forwarding fee buffer.
- A bid with less than one hour remaining resets the deadline to one hour from the bid; exactly one hour remaining does not extend.
- No bid history is stored.
- **100% of every settled winning bid** is allocated to the single auction revenue address configured in the Registry at deployment: `0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi`.
- When an auction is settled, its item contract sends **the entire winning bid** to the immutable revenue address in the same transaction. No claim request or manual withdrawal is required.
- The payout uses `BounceMode.RichBounce`. If the revenue transfer bounces, the item records the full payout amount in `claimablePayout`; anyone can trigger `RetryPlateItemPayout`, and a second bounce restores the liability.
- Outbid refunds also use `BounceMode.RichBounce`. If a refund bounces, the item records the full amount in a per-bidder `claimableRefunds` map and increases `claimableRefundTotal`. The original bidder can later call `ClaimPlateItemRefund`; a failed claim restores the liability. The claim must include a 0.05 TON fee buffer.
- Settlement, payout retry and refund claims preserve active bid escrow, existing payout/refund liabilities and the minimum storage reserve.
- If Registry cannot deploy an item, it records the bounced value as a claimable Registry refund. The original bidder uses `ClaimRegistryRefund`; a failed claim is restored by RichBounce. Duplicate first-bid requests against an existing item are likewise recorded as claimable refunds in that item.

## NFT ownership lifecycle

- The one-year ownership period begins when an auction is settled and the winner becomes owner.
- The current owner may renew before expiration by sending `RenewPlateOwnership`; renewal restarts the one-year period from that transaction.
- Ownership transfer is owner-authorized and restarts the one-year period for the recipient.
- Expiration does not create an auction automatically. The next valid first-bid request reuses the same deterministic item contract and starts a new one-hour auction.
- Each settled auction sends its full winning bid immediately; there are no stored owner, treasury or security payout liabilities.
- No renewal price has been configured yet; the renewal message currently requires only network fees.

## Implementation status

The Registry-to-item deployment path, per-item auctions, settlement accounting, basic ownership transfer, annual renewal and expiration-triggered release are present in source. CI currently passes 23 TVM tests (15 PlateItem and 8 Registry), plus build, formatting, lint and JavaScript specification checks. The tested paths include payout bounce/retry, outbid refund bounce/claim, Registry deployment bounce/claim and duplicate first-bid refund accounting. Multi-bounce adversarial cases, action-phase accounting, frontend integration and a confirmed Testnet deployment remain incomplete. The Registry deployment script is `scripts/deploy-registry.tolk`; CI executes it in local emulation.

## Source attribution

The DNS/NFT Tolk reference modules are based on the official ton-blockchain/acton-contracts Tolk DNS implementation and the original ton-blockchain/dns-contract project. The upstream GPL-3.0 license is retained at contracts/vendor/ton-dns/LICENSE. Do not remove upstream attribution or license notices.
