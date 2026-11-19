# TagitalSpace Testnet deployment configuration

**Network:** TON Testnet (network id -3)

## Auction revenue recipient

The Registry collection must be initialized with this exact address as
`auctionRevenueAddress`:

```text
0QAlaQjrvRz8GCm2IJ1QXA6rNGSyyYfH6uNPT0RzKja6VsLi
```

This is a testnet-friendly TON address (workchain 0). Do not replace it with
the collection owner's wallet or the former development/security fund address.

## Registry initial storage

Build the Registry initial data with the existing initializer:

```tolk
tagitalSpaceRegistryCreateInitialStorage(
    collectionOwnerAddress,
    auctionRevenueAddress,
    compiledPlateItemCode,
)
```

For this deployment, `auctionRevenueAddress` must be the address above.
The Registry has no message that can change this field after deployment.
The Registry passes the stored address to each new deterministic PlateItem;
each item retains that address for its lifetime, including after reauction.

## How auction proceeds are paid

1. The winning bid remains escrowed in that plate's item contract until settlement.
2. After the deadline, any wallet can send `SettlePlateAuction`.
3. In the settlement transaction, the item sends exactly 100% of the winning
   bid to `auctionRevenueAddress`. Network fees are paid separately from the
   item's remaining balance, which must retain its storage reserve.
4. There is no 50/30/20 split, no treasury balance and no manual claim step.

The payout message is currently non-bounceable. Bounce recovery and actual
TVM action-phase behavior are not yet verified, so this configuration is not
a deployment approval. Compile the Tolk contracts and pass the settlement,
balance-reserve and Testnet end-to-end tests before deploying or using funds.

## Current deployment limitation

The repository does not yet contain a Registry deployment script. The address
above is documented as the required initializer value, but no Registry has
been deployed or configured on Testnet by this change.
