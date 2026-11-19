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
- Settlement records 50/30/20 payout liabilities in the plate item. The collection owner and security fund claim directly; the Registry owner triggers the Registry's treasury claim. The payout transfers are currently non-bounceable and have not been tested in TVM.

## Blocking findings

### Critical — build and TVM behavior are unverified

The new project-specific Tolk files, including the new claim flow, have not yet been compiled or executed in TVM tests. Message layouts, StateInit address derivation, storage serialization and all action-phase behavior must be verified before deployment.

### Critical — escrow and bounce safety are incomplete

Bid amounts are now explicit message fields, separate from attached TON reserves. The Registry requires an opening payment buffer and each item records only the configured starting bid. Outbid refunds still use direct non-bounceable messages and do not have a separately tracked refund liability. Settlement payouts are now recorded as three claimable balances, but claim transfers are also non-bounceable and there is no bounce-recovery path. Action-phase rollback, fee coverage, repeated claims and recipient behavior are unverified. This remains a critical blocker before real funds are used.

### High — Registry deployment configuration is incomplete

Registry storage now requires the owner address, development/security address and NFT item code. The deployment initializer and deterministic item code hash/address checks must be wired and tested.

### High — item lifecycle and renewal economics need further verification

NFT ownership is recorded after settlement and can be transferred by its current owner after the auction. The item now supports owner-only annual renewal and expiration-triggered release on the next first-bid request; unpaid settlement liabilities are retained and accumulated across reauctions. Renewal currently has no configured protocol fee. Safe recovery from failed payout actions remains unimplemented.

### High — treasury withdrawal is intentionally absent

The old unverified withdrawal stub was removed. A withdrawal flow must not be restored until it has bounce-safe accounting and authorization tests.

### High — frontend integration is not verified

The browser registry client and frontend message construction must be checked against the new per-item contract addresses, opcodes and getters.

## Required verification gates

1. Tolk formatter, compiler and Acton build.
2. TVM tests for Registry deployment, deterministic StateInit, duplicate first-bid requests, first bid, 5% minimum, 3,600-second boundary, outbid refund, settlement and distribution.
3. Bounce tests proving no bid, refund, owner payout, treasury deposit or security payout can be lost.
4. Accounting invariants for active escrow, refund liabilities and payout liabilities.
5. Testnet end-to-end auction using controlled wallets.
6. Independent security review of the final compiled contracts and deployment configuration.

JavaScript source checks and documentation are not proof of compilation, TVM correctness or security. Do not deploy or send real funds until every gate passes.
