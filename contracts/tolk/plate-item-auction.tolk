import "plate-item-state"
import "plate-item-messages"

const TAGITALSPACE_ITEM_AUCTION_DURATION = 3600;
const TAGITALSPACE_ITEM_OWNERSHIP_PERIOD = 365 * 24 * 60 * 60;
const TAGITALSPACE_ITEM_MIN_STORAGE = grams("0.05");

fun tagitalSpaceProcessPlateBid(
    senderAddress: address,
    valueCoins: coins,
    bidAmount: coins,
    mutate storage: PlateItemStorageInitialized,
    mutate auction: PlateAuctionState,
) {
    assert (blockchain.now() <= auction.auctionEndTime) throw 770;
    assert (bidAmount >= auction.highestBid * 105 / 100) throw 771;
    assert (valueCoins >= bidAmount) throw 772;
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
    // The entire winning bid is sent to the collection's fixed revenue address
    // in the same transaction that settles the auction.
    assert (
        contract.getOriginalBalance() >= auction.highestBid + TAGITALSPACE_ITEM_MIN_STORAGE
    ) throw 786;
    storage.ownerAddress = auction.highestBidder;
    storage.lastRenewalTime = blockchain.now();
    storage.auction = null;
    storage.save();
    val payout = createMessage({
        bounce: BounceMode.NoBounce,
        dest: storage.auctionRevenueAddress,
        value: auction.highestBid,
        body: PlateItemExcesses { queryId },
    });
    payout.send(SEND_MODE_PAY_FEES_SEPARATELY);
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
