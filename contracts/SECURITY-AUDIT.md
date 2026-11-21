# Pre-deployment security review

Date: 2026-11-21  
Repository: `zientres/tagitalspace`  
Reviewed branch: `audit/combined-liability-tests`

## Scope and conclusion

This is a source-level review of the current Tolk contracts, emulator tests, deployment configuration and CI checks. It is not an independent third-party smart-contract audit.

**Deployment verdict: NOT APPROVED.** The current branch passes its automated checks, but fee-exhaustion behavior, storage economics and live Testnet integration still require validation. Do not deploy to Mainnet or accept real funds on the basis of this review.

## Architecture reviewed

- Registry validates the canonical plate and supported Russian region, derives the deterministic item StateInit and forwards the first bid.
- Each plate has its own contract and auction state; there is no shared Auction Manager.
- Later bids, settlement, owner lifecycle, payout recovery and bidder refund recovery are handled by the item.
- 100% of a settled winning bid is sent to the immutable revenue address configured in Registry storage.
- Failed Registry deployments and bounced refunds are recorded as claimable liabilities.

## Findings addressed in this branch

### Balance accounting

The reserve checks use `contract.getOriginalBalance()`, which includes the inbound value credited before compute. The checks no longer add that inbound value a second time. The bid path explicitly preserves the previous escrow and liabilities while accounting for the new bid.

### Liability preservation

Solvency checks cover active bid escrow, pending payout, aggregate bidder refunds and minimum storage. Additional checks now prevent a new auction bid or a duplicate-request refund from masking an existing shortfall. Registry deployment-bounce recovery likewise checks that old refunds remain backed before recording another refund.

### Bounce validation and recovery

Payout and refund bounce handlers validate the original opcode, expected sender/recipient and original message amount. Claimable refunds are tracked per address with an aggregate total. Claims clear the liability before sending; a failed delivery restores it when the actual balance can cover the restored amount and fee reserve.

### Action-phase failure behavior

The emulator suite now exercises action-phase exit code 37 for outbid refunds, settlement payouts, payout retries, refund claims and Registry item deployment. These tests assert transaction rollback and preservation of the relevant auction/liability state.

A failed action phase does not guarantee that the inbound message will bounce: the bounce phase also needs enough value to pay its forwarding fee. Under the deliberately stressed 5.5 TON forwarding-fee configuration, the tests correctly do not expect a bounce when the inbound value is smaller than that fee. No recipient payment is emitted and the contract state remains unchanged.

### Low-value message spam

Both contracts reject internal messages carrying less than 0.05 TON before processing their body. Tests verify that dust messages cannot make the contracts pay compute fees out of existing escrow or refund balances.

## Automated verification

The latest branch head passed GitHub Actions:

- Acton 1.2.1 contract build.
- **35 TVM tests passed**: 23 PlateItem and 12 Registry.
- Registry deployment script in local emulation.
- Tolk formatting and lint.
- Browser JavaScript syntax and Russia page checks.
- Pricing, timing, identity and protocol specification vectors.

These checks establish only the behavior covered by the tests; they are not proof of safety under every TON network configuration.

## Remaining risks and deployment blockers

1. **Fee buffers are fixed constants.** The 0.05 TON storage/forwarding buffers are not dynamically derived from the active TON configuration. Stress tests prove that action-phase failures roll back state, but do not prove that every possible bounce can be funded or that every bounced liability can always be restored. Validate against current Testnet configuration and worst-case message sizes/fees.
2. **Refund dictionaries can grow.** Per-bidder refund maps have no explicit cardinality bound or storage-fee funding policy. Long-lived contracts need a defined storage-economics plan.
3. **No live Testnet end-to-end validation.** Wallet connection, first bid, outbid, settlement, payout bounce, refund claims, expiration and re-auction have not been validated against deployed contracts and real Testnet transactions.
4. **TEP-62 transfer is intentionally disabled.** The standard transfer opcode is rejected; the item is read-only compatible for indexing and uses a separate owner-authorized transfer flow. Marketplace sale/transfer compatibility must not be assumed.
5. **Independent review is still required.** Review the final compiled code, StateInit derivation, deployment parameters and operational wallet controls before any real funds are accepted.

## Required next gates

1. Validate fee and bounce behavior against the active TON Testnet configuration, including larger message bodies and repeated bounce sequences.
2. Define a storage-fee and refund-map growth policy.
3. Deploy only to Testnet with controlled wallets and verify the deployed code hashes and deterministic item addresses.
4. Run the full wallet flow and inspect real transaction traces.
5. Obtain an independent security review of the final compiled contracts.
