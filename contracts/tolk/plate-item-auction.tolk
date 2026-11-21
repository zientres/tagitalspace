import "plate-item-messages"
import "plate-item-state"

const TAGITALSPACE_ITEM_AUCTION_DURATION = 3600
const TAGITALSPACE_ITEM_OWNERSHIP_PERIOD = 365 * 24 * 60 * 60
const TAGITALSPACE_ITEM_MIN_STORAGE = grams("0.05")
const TAGITALSPACE_ITEM_MIN_MESSAGE_VALUE = grams("0.05")
const TAGITALSPACE_ITEM_PAYOUT_FEE_BUFFER = grams("0.05")
const TAGITALSPACE_ITEM_REFUND_FEE_BUFFER = grams("0.05")

fun tagitalSpaceItemActiveBidAmount(storage: PlateItemStorageInitialized): coins {
    if (storage.auction == null) {
        return 0;
    }
    return storage.auction.load().highestBid;
}

fun tagitalSpaceRecordClaimableRefund(
    recipient: address,
    amount: coins,
    mutate storage: PlateItemStorageInitialized,
) {
    assert (amount > 0) throw 799;
    var refunds = storage.claimableRefunds;
    val previous = refunds.get(recipient);
    var claimableAmount = amount;
    if (previous.isFound) {
        claimableAmount += previous.loadValue();
    }
    refunds.set(recipient, claimableAmount);
    storage.claimableRefunds = refunds;
    storage.claimableRefundTotal += amount;
}

fun tagitalSpaceProcessPlateBid(
    senderAddress: address,
    valueCoins: coins,
    bidAmount: coins,
    mutate storage: PlateItemStorageInitialized,
    auctionState: PlateAuctionState,
) {
    var auction = auctionState;
    assert (blockchain.now() <= auction.auctionEndTime) throw 770;
    assert (bidAmount >= auction.highestBid * 105 / 100) throw 771;
    assert (valueCoins >= bidAmount + TAGITALSPACE_ITEM_REFUND_FEE_BUFFER) throw 772;

    // getOriginalBalance already includes this incoming bid. Require the
    // pre-existing balance, excluding the new bid, to cover all old liabilities.
    assert (
        contract.getOriginalBalance() >=
        valueCoins + auction.highestBid + storage.claimablePayout + storage.claimableRefundTotal +
        TAGITALSPACE_ITEM_MIN_STORAGE
    ) throw 772;

    val refund = createMessage({
        bounce: BounceMode.RichBounce,
        dest: auction.highestBidder,
        value: auction.highestBid,
        body: PlateItemBidRefund {
            queryId: blockchain.logicalTime() as uint64,
            recipient: auction.highestBidder,
            amount: auction.highestBid,
        },
    });
    refund.send(SEND_MODE_PAY_FEES_SEPARATELY + SEND_MODE_BOUNCE_ON_ACTION_FAIL);

    auction.highestBidder = senderAddress;
    auction.highestBid = bidAmount;
    if (auction.auctionEndTime - blockchain.now() < TAGITALSPACE_ITEM_AUCTION_DURATION) {
        auction.auctionEndTime = blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION;
    }
    storage.auction = auction.toCell();
    storage.save();
}

fun tagitalSpaceSettlePlateAuction(
    mutate storage: PlateItemStorageInitialized,
    auction: PlateAuctionState,
    queryId: uint64,
) {
    assert (blockchain.now() > auction.auctionEndTime) throw 773;
    assert (storage.ownerAddress == null) throw 774;
    // getOriginalBalance already includes the inbound settlement message value.
    // Preserve previous payout/refund liabilities and the item storage reserve.
    assert (
        contract.getOriginalBalance() >=
        auction.highestBid + storage.claimablePayout + storage.claimableRefundTotal +
        TAGITALSPACE_ITEM_MIN_STORAGE +
        TAGITALSPACE_ITEM_PAYOUT_FEE_BUFFER
    ) throw 786;
    val immutable = storage.immutable.load();
    storage.ownerAddress = auction.highestBidder;
    storage.lastRenewalTime = blockchain.now();
    storage.auction = null;
    storage.save();
    val payout = createMessage({
        bounce: BounceMode.RichBounce,
        dest: immutable.auctionRevenueAddress,
        value: auction.highestBid,
        body: PlateItemRevenuePayout {
            queryId,
            amount: auction.highestBid,
        },
    });
    payout.send(SEND_MODE_PAY_FEES_SEPARATELY + SEND_MODE_BOUNCE_ON_ACTION_FAIL);
}

fun tagitalSpaceRetryPlatePayout(
    mutate storage: PlateItemStorageInitialized,
    queryId: uint64,
) {
    val amount = storage.claimablePayout;
    assert (amount > 0) throw 787;
    // getOriginalBalance already includes the inbound retry message value.
    // Keep all bidder refunds, any active bid, and storage funded while retrying.
    assert (
        contract.getOriginalBalance() >=
        amount + storage.claimableRefundTotal + tagitalSpaceItemActiveBidAmount(storage) +
        TAGITALSPACE_ITEM_MIN_STORAGE +
        TAGITALSPACE_ITEM_PAYOUT_FEE_BUFFER
    ) throw 788;
    val immutable = storage.immutable.load();
    storage.claimablePayout = 0;
    storage.save();
    val payout = createMessage({
        bounce: BounceMode.RichBounce,
        dest: immutable.auctionRevenueAddress,
        value: amount,
        body: PlateItemRevenuePayout { queryId, amount },
    });
    payout.send(SEND_MODE_PAY_FEES_SEPARATELY + SEND_MODE_BOUNCE_ON_ACTION_FAIL);
}

fun tagitalSpaceClaimPlateItemRefund(
    senderAddress: address,
    mutate storage: PlateItemStorageInitialized,
    queryId: uint64,
) {
    var refunds = storage.claimableRefunds;
    val lookup = refunds.get(senderAddress);
    assert (lookup.isFound) throw 800;
    val amount = lookup.loadValue();
    assert (amount > 0) throw 800;
    assert (storage.claimableRefundTotal >= amount) throw 800;

    // getOriginalBalance already includes the inbound claim message value.
    // Refund claims may not consume the active auction escrow, revenue payout
    // liability, other bidders' refunds, or the minimum storage reserve.
    assert (
        contract.getOriginalBalance() >=
        storage.claimableRefundTotal + storage.claimablePayout +
        tagitalSpaceItemActiveBidAmount(storage) +
        TAGITALSPACE_ITEM_MIN_STORAGE +
        TAGITALSPACE_ITEM_REFUND_FEE_BUFFER
    ) throw 801;

    refunds.delete(senderAddress);
    storage.claimableRefunds = refunds;
    storage.claimableRefundTotal -= amount;
    storage.save();

    val refund = createMessage({
        bounce: BounceMode.RichBounce,
        dest: senderAddress,
        value: amount,
        body: PlateItemBidRefund {
            queryId,
            recipient: senderAddress,
            amount,
        },
    });
    refund.send(SEND_MODE_PAY_FEES_SEPARATELY + SEND_MODE_BOUNCE_ON_ACTION_FAIL);
}

fun tagitalSpaceRenewPlateOwnership(
    senderAddress: address,
    mutate storage: PlateItemStorageInitialized,
) {
    assert (storage.auction == null) throw 795;
    assert (storage.ownerAddress != null) throw 796;
    assert (senderAddress == storage.ownerAddress) throw 797;
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
    assert (senderAddress == storage.ownerAddress) throw 792;
    assert (newOwnerAddress.getWorkchain() == BASECHAIN) throw 793;
    storage.ownerAddress = newOwnerAddress;
    storage.lastRenewalTime = blockchain.now();
    storage.save();
}
