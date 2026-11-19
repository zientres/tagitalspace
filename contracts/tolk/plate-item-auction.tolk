import "plate-item-state"
import "plate-item-messages"

const TAGITALSPACE_ITEM_AUCTION_DURATION = 3600;
const TAGITALSPACE_ITEM_MIN_STORAGE = grams("0.05");

fun tagitalSpaceProcessPlateBid(
    senderAddress: address,
    valueCoins: coins,
    mutate storage: PlateItemStorageInitialized,
    mutate auction: PlateAuctionState,
) {
    assert (blockchain.now() <= auction.auctionEndTime) throw 770;
    assert (valueCoins >= auction.highestBid * 105 / 100) throw 771;

    // The previous bid is returned from the item balance while retaining
    // a small storage reserve. The transaction is atomic with the new leader.
    val balanceBeforeMessage = contract.getOriginalBalance() - valueCoins;
    val refundable = balanceBeforeMessage - TAGITALSPACE_ITEM_MIN_STORAGE;
    val refundAmount = auction.highestBid < refundable ? auction.highestBid : refundable;
    assert (refundAmount >= auction.highestBid) throw 772;

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
    queryId: uint64,
) {
    assert (blockchain.now() > auction.auctionEndTime) throw 773;
    assert (storage.ownerAddress == null) throw 774;

    // Persist settlement before outbound payments. The winning bidder becomes
    // the NFT owner exactly once; distribution is split 50/30/20.
    storage.ownerAddress = auction.highestBidder;
    storage.auction = null;
    storage.save();

    val ownerShare = auction.highestBid * 50 / 100;
    val treasuryShare = auction.highestBid * 30 / 100;
    val securityShare = auction.highestBid - ownerShare - treasuryShare;

    val ownerPayment = createMessage({
        bounce: false,
        dest: storage.collectionOwner,
        value: ownerShare,
        body: PlateItemExcesses { queryId },
    });
    ownerPayment.send(SEND_MODE_PAY_FEES_SEPARATELY);

    val treasuryPayment = createMessage({
        bounce: false,
        dest: storage.collectionAddress,
        value: treasuryShare,
        body: RegistryTreasuryDeposit { queryId },
    });
    treasuryPayment.send(SEND_MODE_PAY_FEES_SEPARATELY);

    val securityPayment = createMessage({
        bounce: false,
        dest: storage.developmentSecurityFund,
        value: securityShare,
        body: PlateItemExcesses { queryId },
    });
    securityPayment.send(SEND_MODE_PAY_FEES_SEPARATELY);
}
