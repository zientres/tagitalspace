import "plate-item-state"
import "plate-item-messages"
import "registry-messages"

const TAGITALSPACE_ITEM_AUCTION_DURATION = 3600;
const TAGITALSPACE_ITEM_OWNERSHIP_PERIOD = 365 * 24 * 60 * 60;
const TAGITALSPACE_ITEM_MIN_STORAGE = grams("0.05");

fun tagitalSpaceProcessPlateBid(
    senderAddress: address,
    valueCoins: coins,
    mutate storage: PlateItemStorageInitialized,
    mutate auction: PlateAuctionState,
) {
    assert (blockchain.now() <= auction.auctionEndTime) throw 770;
    assert (valueCoins >= auction.highestBid * 105 / 100) throw 771;

    // Return the previous escrowed bid. The item keeps its storage reserve;
    // if the old bid cannot be returned in full, the transaction is rejected.
    val balanceBeforeMessage = contract.getOriginalBalance();
    assert (balanceBeforeMessage >= auction.highestBid + TAGITALSPACE_ITEM_MIN_STORAGE) throw 772;

    val refund = createMessage({
        bounce: false,
        dest: auction.highestBidder,
        value: auction.highestBid,
        body: PlateItemOutbid { queryId: blockchain.logicalTime() as uint64 },
    });
    refund.send(SEND_MODE_PAY_FEES_SEPARATELY);

    auction.highestBidder = senderAddress;
    auction.highestBid = valueCoins;

    if (auction.auctionEndTime - blockchain.now() < TAGITALSPACE_ITEM_AUCTION_DURATION) {
        auction.auctionEndTime = blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION;
    }

    storage.auction = auction.toCell();
    storage.save();
}

fun tagitalSpaceSettlePlateAuction(
    mutate storage: PlateItemStorageInitialized,
    auction: PlateAuctionState,
    _queryId: uint64,
) {
    assert (blockchain.now() > auction.auctionEndTime) throw 773;
    assert (storage.ownerAddress == null) throw 774;

    // Settlement creates three explicit liabilities. Funds remain in this
    // item contract until each configured beneficiary claims their share.
    storage.ownerAddress = auction.highestBidder;
    storage.lastRenewalTime = blockchain.now();
    storage.auction = null;
    storage.pendingOwnerPayout = auction.highestBid * 50 / 100;
    storage.pendingTreasuryPayout = auction.highestBid * 30 / 100;
    storage.pendingSecurityPayout =
        auction.highestBid - storage.pendingOwnerPayout - storage.pendingTreasuryPayout;
    storage.save();
}

fun tagitalSpaceClaimPlatePayout(
    senderAddress: address,
    queryId: uint64,
    beneficiaryKind: uint8,
    mutate storage: PlateItemStorageInitialized,
) {
    var amount: coins = 0;
    if (beneficiaryKind == 0) {
        assert (senderAddress == storage.collectionOwner) throw 779;
        amount = storage.pendingOwnerPayout;
        assert (amount > 0) throw 780;
        storage.pendingOwnerPayout = 0;
    } else if (beneficiaryKind == 1) {
        assert (senderAddress == storage.collectionAddress) throw 781;
        amount = storage.pendingTreasuryPayout;
        assert (amount > 0) throw 782;
        storage.pendingTreasuryPayout = 0;
    } else if (beneficiaryKind == 2) {
        assert (senderAddress == storage.developmentSecurityFund) throw 783;
        amount = storage.pendingSecurityPayout;
        assert (amount > 0) throw 784;
        storage.pendingSecurityPayout = 0;
    } else {
        throw 785;
    }

    // Preserve the item's storage reserve; the claim is only cleared in the
    // same transaction that queues its non-bounceable value transfer.
    assert (
        contract.getOriginalBalance() >= amount + TAGITALSPACE_ITEM_MIN_STORAGE
    ) throw 786;
    storage.save();

    if (beneficiaryKind == 1) {
        val payout = createMessage({
            bounce: BounceMode.NoBounce,
            dest: storage.collectionAddress,
            value: amount,
            body: RegistryTreasuryDeposit {
                queryId,
                identityKey: storage.identityKey,
            },
        });
        payout.send(SEND_MODE_PAY_FEES_SEPARATELY);
    } else {
        val payout = createMessage({
            bounce: BounceMode.NoBounce,
            dest: senderAddress,
            value: amount,
            body: PlateItemExcesses { queryId },
        });
        payout.send(SEND_MODE_PAY_FEES_SEPARATELY);
    }
}

fun tagitalSpaceRenewPlateOwnership(
    senderAddress: address,
    mutate storage: PlateItemStorageInitialized,
) {
    assert (storage.auction == null) throw 795;
    assert (storage.ownerAddress != null) throw 796;
    assert (senderAddress == storage.ownerAddress!) throw 797;
    val expirationTime = storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
    assert (blockchain.now() < expirationTime) throw 798;
    storage.lastRenewalTime = blockchain.now();
    storage.save();
}

fun tagitalSpaceTransferPlateOwnership(
    senderAddress: address,
    newOwnerAddress: address,
    mutate storage: PlateItemStorageInitialized,
) {
    assert (storage.auction == null) throw 790;
    assert (storage.ownerAddress != null) throw 791;
    assert (senderAddress == storage.ownerAddress!) throw 792;
    assert (newOwnerAddress.getWorkchain() == BASECHAIN) throw 793;
    storage.ownerAddress = newOwnerAddress;
    storage.lastRenewalTime = blockchain.now();
    storage.save();
}
