# TagitalSpace contract architecture

Status: implementation in progress; not deployable.
Network: TON Testnet only (network id -3).

## Contract model — TON DNS pattern

TagitalSpace follows the architecture of TON DNS:
- TagitalSpaceRegistry is the collection contract. It validates the plate and Russian region, derives a deterministic item address from the item code and identity, and deploys that item with the first bid.
- TagitalSpacePlateItem is a separate contract for each unique (plate body, region) pair. It stores that plate's auction state and handles later bids, outbid refunds, deadline extension, settlement and NFT ownership.
- There is no Auction Manager and no shared contract that stores or operates all auctions.
- The item address is deterministic from the identity key and Registry address, matching the DnsCollection / DnsItem StateInit pattern.
- Repeating a first-bid request for an existing item must not overwrite its auction; the initialized item returns the attached value to the new requester.
- If a newly requested item deployment fails, the Registry validates the RichBounce against the deterministic item address and original init payload, then refunds the bounced value (minus network fees) to the first bidder.

## Identity and uniqueness

- Canonical plate body is exactly six ASCII characters: letter, three digits, two letters, using A B E K M H O P C T Y X.
- Region is separate and validated against the Russia allowlist (212 supported codes; 20 excluded).
- Identity is (canonical plate body, region code). The same body may exist in another region.
- Starting price depends on the six-character body only.

## Auction policy

- Any wallet may start an auction by submitting the first bid through Registry.
- Starting price: base 3 TON; mirrored letters 15 TON; mirrored digits 15 TON; triples 50 TON; both blocks add; base applies only when no special pattern applies; triple does not stack with mirror pricing in its own block.
- Each item's first bid initializes its local auction state.
- The bid amount is encoded explicitly in the message and is separate from attached TON used for fees and reserve. The first bid is fixed to the calculated starting price; later attached excess is not counted as part of the bid.
- Registry requires starting price + 0.15 TON before forwarding the deployment message. The item separately checks that at least its 0.05 TON storage reserve arrives after forwarding fees.
- Later bids must be at least floor(current bid × 105 / 100) and attach at least 0.05 TON above the explicit bid amount to cover refund forwarding/bounce fees.
- Initial duration is 3,600 seconds. A bid with strictly less than 3,600 seconds remaining extends the deadline to now + 3,600; exactly 3,600 seconds does not extend.
- No bid history is stored.
- Outbid refunds use RichBounce. If a refund bounces, the item stores the full refund liability in a per-bidder map; the original bidder can claim it later. A failed claim bounces back into the same liability map.
- Anyone may trigger settlement after the deadline; the item contract persists the winner as owner and clears the auction once.

## Auction revenue destination

**100% of each settled winning bid goes to one fixed address:** `0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi`.

The Registry stores this address in its initial data and passes it into every deterministic plate item at initialization. When anyone triggers settlement after the deadline, the item sends the entire winning bid directly to that stored revenue address in the same transaction. There is no split, claim step or caller-controlled destination. The payout uses `BounceMode.RichBounce`. A failed payout is recorded in `claimablePayout` by the item's bounce handler and can be retried by sending `RetryPlateItemPayout`. The retry clears the liability before sending and relies on a subsequent RichBounce to restore it if the retry also fails. Outbid refund liabilities are tracked separately per bidder, with an aggregate total used to protect escrow and storage reserves. The bidder must attach a fee buffer when claiming. Both payout and outbid-refund recovery have emulator tests, but action-phase edge cases and adversarial bounce handling still require review.

## NFT lifecycle

The per-plate item is itself the NFT item contract. Its deterministic StateInit includes the Registry address and identity key. Before settlement it reports no owner; after settlement the highest bidder becomes owner. Basic owner-authorized NFT transfer is implemented. Each item has a one-year ownership period measured from settlement (when the winner becomes owner), its last renewal, or ownership transfer. The current owner may renew before expiration; each successful renewal resets the one-year period from the renewal time. After expiration, the next valid first-bid request can restart the auction in the same deterministic item contract. Expiration does not start an auction by itself. Every settled auction immediately sends its complete winning bid to the configured revenue address; no unpaid payout balance is retained. A separate renewal price has not been configured; renewal currently requires only the on-chain owner message and network fees.

## Required verification before deployment

1. Tolk compile, formatter and Acton build.
2. TVM tests for item deployment, duplicate identity, bid thresholds, deadline boundaries, refund accounting, settlement payout and reserve accounting.
3. StateInit/address derivation tests proving different regions produce different item addresses.
4. Testnet end-to-end auction with controlled wallets.
5. Independent security review of compiled contracts and deployment configuration.

JavaScript source checks and design notes are not proof of Tolk compilation, TVM correctness or security.
