# TagitalSpace Testnet deployment

**Target network:** TON Testnet only (network id -3).  
**Mainnet deployment is not approved.**

## Fixed auction revenue recipient

The Registry must be initialized with this exact address as `auctionRevenueAddress`:

```text
0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi
```

The Registry passes this address to every per-plate item. It cannot be changed after deployment.

## What the deployment script does

`scripts/deploy-registry.tolk`:

1. asks you to select the Registry owner/deployer wallet;
2. builds the current `TagitalSpacePlateItem` code cell;
3. initializes Registry storage, including empty refund-liability maps;
4. deploys the Registry with 0.2 TON attached;
5. waits for the transaction trace and verifies the revenue-recipient getter;
6. prints the Registry address and a sample deterministic item address.

The script deploys only the Registry. Individual plate item contracts are deployed lazily when a user starts the first bid for a plate.

## Safe execution order

First build and run the full local test suite:

```bash
source "$HOME/.acton/bin/env"
acton build
acton test
acton script scripts/deploy-registry.tolk
```

The script without `--net` runs in local emulation and does not broadcast transactions.

Only after the local run succeeds, deploy to Testnet:

```bash
acton script scripts/deploy-registry.tolk --net testnet
```

Alternatively, connect a wallet through TON Connect:

```bash
acton script scripts/deploy-registry.tolk --net testnet --tonconnect
```

The selected wallet must be funded with Testnet TON. Review the wallet address, deployment value and printed Registry address before approving the transaction. Do not use `--net mainnet`.

## Refund and auction accounting

- A failed Registry-to-item deployment is recorded as a claimable Registry refund. The original bidder withdraws it with `ClaimRegistryRefund`.
- A duplicate first-bid request against an existing item is recorded as a claimable refund in that item.
- A bounced outbid refund is recorded per bidder; the bidder withdraws it with `ClaimPlateItemRefund`.
- A failed refund claim is restored by RichBounce. Claim transactions must include the configured fee buffer.
- A settled winning bid is sent in full to the fixed revenue address using RichBounce. If it bounces, the item records `claimablePayout` and can retry it with `RetryPlateItemPayout`.
- The Registry and item expose the read-only TEP-62 collection/item getters and on-chain TEP-64 metadata. The standard TEP-62 transfer opcode is rejected intentionally; TagitalSpace's custom owner-authorized transfer remains separate. Actual Getgems Testnet indexing, SVG rendering and failed sale behavior must be verified after deploying and minting a test item.
- Settlement, payout retries and refund claims preserve active auction escrow, outstanding refund/payout liabilities and the minimum storage reserve.

These flows have emulator coverage, but the current source-level review is not an independent security audit. Multi-bounce adversarial cases, action-phase accounting, Testnet end-to-end behavior, frontend integration and independent review remain required before using real funds.

## Current status

The Registry deployment script is implemented and is exercised by CI in local emulation. No Registry has been deployed to Testnet by this change. Save the printed Registry address after a successful Testnet deployment; do not assume an address before the deployment transaction is confirmed.
