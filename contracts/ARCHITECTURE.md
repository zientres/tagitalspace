# TagitalSpace contract architecture (implementation specification)

Status: design baseline; not deployable.
Network: TON Testnet only (network id -3).

## Identity and uniqueness
- Canonical plate body is exactly six ASCII characters: letter, three digits, two letters (Russian allowed alphabet mapped to A B E K M H O P C T Y X).
- Region is a separate validated field.
- Registry identity is the pair (canonical plate body, region code). A plate body may exist in another region.
- Canonicalization and region validation happen before any state transition.
- No mint/auction operation may bypass the registry's uniqueness reservation.

## Auction policy
- Any wallet may create an auction by submitting the first bid for an unreserved/unowned pair.
- Starting bid is calculated from the six-character body: base 3 TON; mirrored letters 15 TON; mirrored digits 15 TON; triples 50 TON; both mirror blocks add; base is used only if neither special pattern applies; triples are not combined with mirror pricing in the same block.
- Subsequent bid minimum is ceil(current_bid * 105 / 100), avoiding integer-rounding underpayment. This rounding convention must be implemented consistently and tested.
- Auction starts with 3600 seconds.
- When a bid arrives with less than 3600 seconds remaining, end time becomes now + 3600; at exactly 3600 seconds or more, no extension.
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
