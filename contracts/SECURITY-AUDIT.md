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
- Settlement sends 100% of the winning bid directly from the item contract to the immutable revenue address `0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi` in the settlement transaction. The transfer uses `BounceMode.RichBounce`; the item has a claimable-payout liability and retry path. The current tests exercise a payout bounce and a failed retry, but do not yet cover every action-phase failure mode or Registry deployment bounce.

## Blocking findings

### Critical — build and TVM behavior are unverified

The new project-specific Tolk files, including the automatic settlement payout, have not yet been compiled or executed in TVM tests. Message layouts, StateInit address derivation, storage serialization and all action-phase behavior must be verified before deployment.

### Critical — escrow and bounce safety are incomplete

Bid amounts are now explicit message fields, separate from attached TON reserves. The Registry requires an opening payment buffer and each item records only the configured starting bid. Outbid refunds still use direct non-bounceable messages and do not have a separately tracked refund liability. Settlement sends the complete winning bid with `BounceMode.RichBounce`. A bounced payout is recorded as a liability and can be retried. However, action-phase rollback, fee coverage, repeated retries, and recipient behavior still need exhaustive TVM tests. Outbid refunds remain non-bounceable and have no separate liability/recovery path. This remains a critical blocker before real funds are used.

### High — Registry deployment configuration is incomplete

Registry storage now requires the owner address, the fixed auction revenue address `0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi`, and NFT item code. The deployment initializer and deterministic item code hash/address checks must be wired and tested.

### High — item lifecycle and renewal economics need further verification

NFT ownership is recorded after settlement and can be transferred by its current owner after the auction. The item now supports owner-only annual renewal and expiration-triggered release on the next first-bid request; each completed auction pays its full proceeds immediately to the configured revenue address. Renewal currently has no configured protocol fee. Safe recovery from failed payout actions remains unimplemented.

### High — Registry deployment bounce recovery is missing

The Registry sends the item deployment with `BounceMode.RichBounce`, but `TagitalSpaceRegistry.tolk` has no `onBouncedMessage` handler. If deployment fails after the Registry forwards the opening bid, the bounced value returns to the Registry rather than being refunded to the initiating wallet. This path needs a verified refund handler and dedicated Registry TVM tests.

### High — outbid refund recovery is missing

Outbid refunds are sent with `bounce: false`. If the previous bidder's address cannot receive the refund, the refund can be lost. There is no tracked refund liability or retry flow.

### High — payout recovery needs more tests

The item has a RichBounce-based liability and retry mechanism for revenue payouts. The configured revenue address is immutable after Registry deployment, so it must be checked carefully before deployment.

### High — frontend Registry client is missing and still targets the old protocol

`From/Russia/Russia.html` loads `registry-client.js` and calls `window.tagitalSpaceRegistry.lookupRussianPlate`, `startRussianAuctionWithFirstBid` and `placeBid`. There is no `registry-client.js` in the current repository tree. The page's auction rendering also expects fields such as `auctionId`, `status`, `startingBid` and `minimumBidStep`, while the current per-item contract exposes a `PlateAuctionState` with `highestBidder`, `highestBid` and `auctionEndTime`. The browser flow is therefore not integrated with the current contract architecture.

### High — current item is not a standard TON NFT implementation

The item uses custom `get_nft_data` fields and a custom `TransferPlateOwnership` opcode (`0x5fcc3d15`), rather than the standard TEP-62 NFT item getter and transfer message protocol. It also lacks the standard collection/content getters and metadata plumbing expected by NFT marketplaces. As written, this contract should not be assumed to appear or trade correctly on Getgems.

### High — Registry TVM coverage is missing

The current test suite exercises the PlateItem contract, but does not deploy and exercise `TagitalSpaceRegistry`. It does not prove first-bid forwarding, deterministic address derivation, duplicate requests, Registry-to-item bounce handling, or refund of a failed item deployment. The Registry path is a critical money-handling path and needs dedicated emulator tests before deployment.

### High — frontend integration is not verified

The browser registry client and frontend message construction must be implemented and checked against the new per-item contract addresses, opcodes and getters.

## Required verification gates

1. Tolk formatter, compiler and Acton build.
2. TVM tests for Registry deployment, deterministic StateInit, duplicate first-bid requests, first bid, 5% minimum, 3,600-second boundary, outbid refund, settlement and distribution.
3. Bounce tests proving no bid refund or auction revenue payout can be lost.
4. Accounting invariants for active escrow, refund liabilities and settlement reserve accounting.
5. Testnet end-to-end auction using controlled wallets.
6. Independent security review of the final compiled contracts and deployment configuration.

JavaScript source checks and documentation are not proof of compilation, TVM correctness or security. Do not deploy or send real funds until every gate passes.
