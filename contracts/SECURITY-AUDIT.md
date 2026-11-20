# Pre-deployment security review

Date: 2026-11-19  
Repository reviewed: zientres/tagitalspace, branch main.

## Scope and conclusion

This is a source-level pre-deployment review, not an independent smart-contract audit. The repository now contains a TagitalSpace Registry collection entrypoint and a per-plate auction item implementation modeled on TON DNS DnsCollection / DnsItem. The current implementation is an early integration slice and is **not safe to deploy**.

## Current architecture

- Registry validates canonical plate identity and Russia region, computes the deterministic item identity, and deploys the item with the first bid.
- Each plate item stores its own auction, bidder and deadline.
- Later bids, outbid refunds and settlement are handled by that item contract.
- No shared Auction Manager is part of the intended architecture.
- Settlement sends 100% of the winning bid directly from the item contract to the immutable revenue address `0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi` in the settlement transaction. The transfer uses `BounceMode.RichBounce`; the item has a claimable-payout liability and retry path. The current tests exercise payout bounce/retry, outbid refund recovery, Registry deployment bounce/claim and duplicate-request refund accounting, but do not cover every action-phase failure mode or all multi-bounce sequences.

## Blocking findings

### Verification progress — build and core TVM paths now pass

The current branch compiles with Acton 1.2.1 and passes 17 TVM tests: 11 PlateItem tests and 6 Registry integration tests. The CI pipeline also passes Tolk formatting, lint and JavaScript specification checks. This verifies the currently covered paths only; it is not an independent audit and does not establish safety for Mainnet. Additional adversarial and action-phase tests remain required.

### Critical — escrow and bounce safety are incomplete

Bid amounts are now explicit message fields, separate from attached TON reserves. The Registry requires an opening payment buffer and each item records only the configured starting bid. Outbid refunds now use `BounceMode.RichBounce`. A bounced refund is recorded in a `map<address, coins>` keyed by the original bidder, with an aggregate liability total. The bidder can claim the amount later; the claim clears the liability before sending and a subsequent RichBounce restores it if delivery fails again. Later bids and claims require explicit fee buffers, and settlement/withdrawal checks preserve active escrow, payout liabilities, refund liabilities and minimum storage. These paths have basic emulator coverage, but multi-bounce sequences, fee exhaustion, action-phase rollback and adversarial recipient behavior still need more tests. This remains a critical blocker before real funds are used.

### High — Testnet deployment has not yet been performed

Registry storage now requires the owner address, the fixed auction revenue address `0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi`, and NFT item code. The Registry deployment script now initializes the fixed revenue address, owner and compiled item code, and is exercised in local emulation by CI. The script has not yet been broadcast to Testnet; on-chain deployment confirmation and an independent check of the deployed StateInit/address remain required.

### High — item lifecycle and renewal economics need further verification

NFT ownership is recorded after settlement and can be transferred by its current owner after the auction. The item now supports owner-only annual renewal and expiration-triggered release on the next first-bid request; each completed auction pays its full proceeds immediately to the configured revenue address. Renewal currently has no configured protocol fee. Payout recovery is implemented, but multi-bounce and fee-exhaustion behavior still needs more testing.

### High — Registry deployment bounce recovery needs expanded testing

The Registry now has an `onBouncedMessage` handler for failed item deployments. It parses the original init payload, recomputes the expected deterministic item address from the plate/region and configured item code, verifies the immutable revenue destination and opening bid, then records the value actually bounced (after network fees) as a claimable refund for the original first bidder. The bidder claims it through `ClaimRegistryRefund`; if that transfer bounces, the Registry restores the liability. Duplicate first-bid requests against an existing item are also recorded as claimable refunds inside that item instead of being sent through a non-bounceable transfer. CI covers a real Registry deployment bounce followed by a successful claim, a failed Registry refund claim that bounces and restores the liability, and a duplicate request that creates a claimable balance. Multi-bounce and action-phase failure cases still require review.

### High — outbid refund recovery needs expanded adversarial testing

The recovery mechanism has been implemented: bounced outbid refunds are tracked per bidder, and the original bidder can claim the stored amount later. Registry deployment failures and duplicate first-bid requests also create claimable balances. CI covers the Registry deployment bounce/claim and failed-claim restoration, duplicate request accounting, an outbid refund bounce/claim and failed-claim restoration, multiple bidder refund isolation, and rejection of mismatched or unexpected refund bounces. Remaining tests should cover repeated failed claims, multiple bidders with simultaneous liabilities, fee exhaustion, and preservation of all liabilities through settlement and renewal.

### High — payout recovery needs more tests

The item has a RichBounce-based liability and retry mechanism for revenue payouts. The configured revenue address is immutable after Registry deployment, so it must be checked carefully before deployment.

### High — frontend Registry client is missing and still targets the old protocol

`From/Russia/Russia.html` loads `registry-client.js` and calls `window.tagitalSpaceRegistry.lookupRussianPlate`, `startRussianAuctionWithFirstBid` and `placeBid`. There is no `registry-client.js` in the current repository tree. The page's auction rendering also expects fields such as `auctionId`, `status`, `startingBid` and `minimumBidStep`, while the current per-item contract exposes a `PlateAuctionState` with `highestBidder`, `highestBid` and `auctionEndTime`. The browser flow is therefore not integrated with the current contract architecture.

### High — current item is not a standard TON NFT implementation

The item uses custom `get_nft_data` fields and a custom `TransferPlateOwnership` opcode (`0x5fcc3d15`), rather than the standard TEP-62 NFT item getter and transfer message protocol. It also lacks the standard collection/content getters and metadata plumbing expected by NFT marketplaces. As written, this contract should not be assumed to appear or trade correctly on Getgems.

### High — Registry TVM coverage is still partial

CI now covers failed item deployment and claim, successful item deployment, duplicate-request refund accounting, invalid plate/region rejection, different deterministic item addresses for different regions, revenue-recipient getter, and owner-only empty-body deployment. Remaining gaps include action-phase failures, StateInit code-hash assertions and repeated claim bounce scenarios.

### High — frontend integration is not verified

The browser registry client and frontend message construction must be implemented and checked against the new per-item contract addresses, opcodes and getters.

## Required verification gates

1. Tolk formatter, compiler and Acton build (currently passing in CI).
2. Expand TVM tests for deterministic StateInit code-hash assertions, repeated outbid refund failures/claims, settlement and distribution. Current CI covers Registry bounce/claim, duplicate request refund accounting, invalid inputs, region-separated addresses and owner-only deployment, plus outbid refund bounce/claim.
3. Bounce tests proving no bid refund or auction revenue payout can be lost.
4. Accounting invariants for active escrow, refund liabilities and settlement reserve accounting.
5. Testnet end-to-end auction using controlled wallets.
6. Independent security review of the final compiled contracts and deployment configuration.

JavaScript source checks and documentation are not proof of compilation, TVM correctness or security. Do not deploy or send real funds until every gate passes.
