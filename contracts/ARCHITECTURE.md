# TagitalSpace contract architecture (implementation specification)

Status: design baseline; not deployable.
Network: TON Testnet only (network id -3).

## Identity and uniqueness
- Canonical plate body is exactly six ASCII characters: letter, three digits, two letters (Russian allowed alphabet mapped to A B E K M H O P C T Y X).
- Region is a separate validated numeric field (1–999 in the generic identity helper); the Russian registry must additionally enforce its explicit supported-region allowlist.
- Registry identity is the pair (canonical plate body, region code). A plate body may exist in another region.
- Canonicalization and region validation happen before any state transition.
- No mint/auction operation may bypass the registry's uniqueness reservation.

## Auction policy
- Any wallet may create an auction by submitting the first bid for an unreserved/unowned pair.
- Starting bid is calculated from the six-character body: base 3 TON; mirrored letters 15 TON; mirrored digits 15 TON; triples 50 TON; both mirror blocks add; base is used only if neither special pattern applies; triples are not combined with mirror pricing in the same block.
- Subsequent bid minimum is floor(current_bid * 105 / 100), matching TON DNS integer arithmetic. The reusable helper is in `contracts/tolk/auction-policy.tolk`; the threshold must be tested at rounding boundaries.
- Auction starts with 3600 seconds (`tagitalSpaceInitialAuctionEndTime`).
- When a bid arrives with less than 3600 seconds remaining, end time becomes now + 3600; at exactly 3600 seconds or more, no extension (`tagitalSpacePolicyAuctionEndTimeAfterBid`).
- No bid history is stored.
- No settlement may occur before deadline. Settlement requires an explicit message/getter-supported state transition; transaction ordering and idempotence must be protected.

## Registry lifecycle
States should be explicit and mutually exclusive: AVAILABLE, AUCTION, MINT_PENDING, OWNED, EXPIRED/RENEWAL_PENDING as appropriate.
- Registry reserves the (plate, region) pair when an auction starts.
- Reservation cannot be duplicated while auction, mint, or ownership is active.
- Auction completion transitions to MINT_PENDING before deployment/notification, never directly to OWNED.
- Only a verified successful mint/acknowledgement transitions to OWNED.
- Failure/bounce paths must safely return to a retryable state without allowing a second mint or losing the reservation/payment accounting.
- Annual renewal is an owner-only operation. Expiration policy and grace period must be explicitly implemented/tested before deployment; expiration should not silently release a pair while settlement is pending.

## Auction manager
- Stores auction state, deadline, current bid and bidder, canonical plate and region, and status.
- Validate sender, attached amount, bid threshold, deadline, state, and uniqueness before changing state.
- Outbid refund and incoming bid accounting must be robust to bounced outbound messages; refund liabilities must not be lost.
- Single-settlement guard and replay protection.
- Any fee reserve and gas calculation must be tested with realistic Testnet messages.

## Distribution
Agreed split of auction proceeds: 50% owner, 30% retained in contract treasury, 20% development/security fund.
- Define whether split applies to gross winning bid or net of gas; this specification assumes the percentages apply to the auction proceeds amount, with gas/reserve accounted separately and explicitly.
- Transfers and treasury balances require accounting invariants, reentrancy/replay protections (message-based), and bounce recovery.
- Treasury withdrawal must be owner-authorized, bounded to accounted funds, and support partial/full withdrawal.
- Development/security wallet must be configurable only through protected owner/admin authorization and preferably a delayed or constrained change mechanism.

## NFT implementation
- NFT item state must encode plate, region, collection/registry identity, owner and renewal timestamps.
- Item StateInit/address derivation must be deterministic and collision-safe.
- Collection and item getters follow a documented NFT standard-compatible interface where applicable.
- Mint acknowledgement is authenticated; duplicate init is rejected.

## Frontend
- Frontend must read registry/auction state from contracts, not trust locally supplied state.
- Wallet must remain locked to Testnet (network -3).
- User-facing bid value is converted and validated; UI is not security authority.
- Registry client must handle pending, confirmed, failed, bounced, and timeout states without claiming a transaction succeeded prematurely.

## Verification gates (all required before deployment)
1. Tolk compile and formatter/linter.
2. Contract tests for identity normalization, pricing, threshold rounding, boundary timing, renewal, and every state transition.
3. TVM tests for message serialization, insufficient value, sender authorization, replay, duplicate reservation, settlement, refund bounce, mint bounce, and treasury withdrawal.
4. Property/invariant tests: one owner per pair, one auction per pair, no double settlement, accounting liabilities preserved, unauthorized state transitions impossible.
5. Testnet end-to-end run with test wallets and controlled funds.
6. Independent security review of the final compiled contracts and deployment configuration.
7. Verify deployment addresses, code hashes, configuration, and wallet/network before deployment.

This specification is a design checklist only; it is not proof of implementation, compilation, or security.


## Current helper implementation status

The first reusable TagitalSpace-specific Tolk helpers now exist:
- `plate-identity.tolk`: canonical plate format, allowed ASCII alphabet, generic numeric region bounds, and identity-cell construction.
- `auction-policy.tolk`: first-bid validation, floor-rounded 5% next-bid threshold, one-hour initial duration, extension boundary, and settlement-time predicate.

These helpers are not yet wired into a deployable Registry or Auction Manager. The generic region bounds are not a substitute for the Russian region allowlist. The independent JavaScript checks are not Tolk/TVM execution evidence.


## Registry storage layout (first draft)

`contracts/tolk/registry-state.tolk` now defines the initial persisted data model:
- Registry entry key: hash of the canonical plate-body + region identity.
- Entry retains the original six-byte plate body and numeric region code for identity verification.
- Explicit states: AUCTION, MINT_PENDING, OWNED, RENEWAL_PENDING. An absent key represents AVAILABLE.
- Auction fields: auction ID/address, highest bidder, highest bid, and deadline.
- Mint/ownership fields: NFT item address, owner, expiry, and pending query ID.
- Registry configuration: owner, development/security fund, and accounted treasury balance.

This is a storage schema only. It does not yet implement registry message handlers, map-key derivation, auction callbacks, mint acknowledgement, renewal, or bounce recovery. The Auction Manager must separately account for bidder escrow and refund liabilities; those funds must not be counted as the registry treasury.


The Russia-specific allowlist is implemented separately in `contracts/tolk/russia-regions.tolk` and mirrors the 212 codes currently used by `From/Russia/Russia.html`; region 20 is excluded. The Russia registry must enforce this allowlist. The generic numeric 1–999 check is not sufficient for a Russia plate.


## Auction Manager storage layout (first draft)

`contracts/tolk/auction-manager-state.tolk` defines:
- Per-auction identity, plate, region, status, highest bidder/bid, deadline, and payout recipients.
- Explicit ACTIVE, SETTLED, and CANCELLED states.
- Separate maps for bidder refunds, owner payouts, and development/security payouts.
- Aggregate liabilities for active bid escrow, refunds, owner payouts, and security payouts.
- A separately accounted 30% treasury balance.

Settlement must be idempotent and move amounts between these accounting buckets exactly once. A previous highest bid becomes a refund liability when outbid; it must not be treated as free contract balance. Payout credits should be claimable and remain liabilities until successfully paid. Any claim implementation must restore a liability on bounced transfers. The storage file itself does not yet implement these transitions.


## Registry message protocol (first draft)

`contracts/tolk/registry-messages.tolk` defines stable opcodes and payload layouts for:
- user request to start a first-bid auction;
- Registry-to-Auction-Manager auction creation;
- authenticated auction-created, rejected, and settled callbacks;
- Registry-to-NFT initialization and NFT success/failure acknowledgements;
- an explicit cancellation request for a separately authorized recovery path.

The protocol carries a query ID and full plate identity through asynchronous transitions. A handler must match the query ID and identity against the stored pending entry, and authenticate the sender contract before applying any callback. A timeout alone is never proof that a remote operation failed; the Registry must not release a reservation solely because a response was delayed.

This file defines message layouts only. It does not implement handlers, serialization tests, sender checks, bounce recovery, or deployment-ready contracts. The opcodes and field layouts must be treated as a versioned interface and covered by TVM serialization tests before integration.


### Asynchronous reservation invariant

The Registry state schema now includes `AUCTION_PENDING` as a distinct reservation state. The required sequence is:
1. Validate the canonical plate and Russia region; derive the identity key.
2. Confirm the key is absent, then persist `AUCTION_PENDING` with a fresh query ID before sending any message.
3. Send `CreateManagedAuction` to the configured Auction Manager.
4. Accept `ManagedAuctionCreated` only from that manager and only when query ID and identity key match; then transition to `AUCTION`.
5. Accept a rejection only under the same authentication and correlation checks; only then may the matching pending reservation be cleared.
6. Treat a bounce or timeout as an unresolved operation until a defined recovery procedure proves the manager did not create the auction.

This ordering prevents two first-bid requests from racing for the same plate-and-region pair. The current schema and message definitions describe the invariant; the transaction handlers and bounce recovery remain unimplemented.
