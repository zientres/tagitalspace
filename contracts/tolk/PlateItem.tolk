import "plate-item-state"
import "plate-item-messages"
import "plate-item-auction"
import "registry-messages"

contract TagitalSpacePlateItem {
    author: "TagitalSpace"
    version: "0.1.0"
    description: "Individual TagitalSpace plate NFT with its own auction"
    incomingMessages: AllowedPlateItemMessage
    storage: PlateItemStorageInitialized
    storageAtDeployment: PlateItemStorageNotInitialized
}

type AllowedPlateItemMessage = PlateItemBid | SettlePlateAuction | RenewPlateOwnership | TransferPlateOwnership

fun onInternalMessage(in: InMessage) {
    val loading = startLoadingPlateItemStorage();

    if (!loading.isInitialized()) {
        val uninitialized = loading.parseNotInitialized();
        assert (in.senderAddress == uninitialized.collectionAddress) throw 775;

        val init = lazy PlateItemInitData.fromSlice(in.body);
        assert (in.valueCoins >= init.firstBidAmount + TAGITALSPACE_ITEM_MIN_STORAGE) throw 776;
        val initialAuction = PlateAuctionState {
            highestBidder: init.firstBidder,
            highestBid: init.firstBidAmount,
            auctionEndTime: blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION,
        };
        val storage = PlateItemStorageInitialized {
            identityKey: uninitialized.identityKey,
            collectionAddress: uninitialized.collectionAddress,
            plateBody: init.plateBody,
            regionCode: init.regionCode,
            auctionRevenueAddress: init.auctionRevenueAddress,
            ownerAddress: null,
            auction: initialAuction.toCell(),
            lastRenewalTime: blockchain.now(),
        };
        storage.save();
        return;
    }

    var storage = loading.parseInitialized();

    // Registry may restart an expired identity, but cannot overwrite a live
    // auction. Each completed auction pays its winning bid immediately.
    if (in.senderAddress == storage.collectionAddress && in.body.preloadUint(32) == 0x54531006) {
        val init = lazy PlateItemInitData.fromSlice(in.body);
        val expirationTime = storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
        val isExpired = storage.ownerAddress != null
            && storage.auction == null
            && blockchain.now() >= expirationTime;
        // Reuse the deterministic item address for the next auction after expiry.
        if (isExpired) {
            storage.ownerAddress = null;
            // Keep the immutable revenue destination configured by the Registry.
            storage.plateBody = init.plateBody;
            storage.regionCode = init.regionCode;
            storage.lastRenewalTime = blockchain.now();
            assert (in.valueCoins >= init.firstBidAmount + TAGITALSPACE_ITEM_MIN_STORAGE) throw 776;
            storage.auction = PlateAuctionState {
                highestBidder: init.firstBidder,
                highestBid: init.firstBidAmount,
                auctionEndTime: blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION,
            }.toCell();
            storage.save();
            return;
        }

        // Duplicate requests and active items are rejected by returning the
        // incoming bid to its sender.
        val refund = createMessage({
            bounce: false,
            dest: init.firstBidder,
            value: 0,
            body: PlateItemExcesses { queryId: blockchain.logicalTime() as uint64 },
        });
        refund.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        return;
    }

    val msg = lazy AllowedPlateItemMessage.fromSlice(in.body);
    match (msg) {
        PlateItemBid => {
            val unpacked = storage.unpackAuction();
            assert (!unpacked.0) throw 777;
            var auction = unpacked.1;
            tagitalSpaceProcessPlateBid(in.senderAddress, in.valueCoins, msg.bidAmount, mutate storage, mutate auction);
        }
        SettlePlateAuction => {
            val unpacked = storage.unpackAuction();
            assert (!unpacked.0) throw 778;
            tagitalSpaceSettlePlateAuction(mutate storage, unpacked.1, msg.queryId);
        }
        RenewPlateOwnership => {
            tagitalSpaceRenewPlateOwnership(in.senderAddress, mutate storage);
        }
        TransferPlateOwnership => {
            tagitalSpaceTransferPlateOwnership(
                in.senderAddress,
                msg.newOwnerAddress,
                mutate storage,
            );
        }
    }
}

get fun get_nft_data(): PlateItemNftData {
    val loading = startLoadingPlateItemStorage();
    if (!loading.isInitialized()) {
        val uninitialized = loading.parseNotInitialized();
        return {
            initialized: false,
            identityKey: uninitialized.identityKey,
            collectionAddress: uninitialized.collectionAddress,
            ownerAddress: null,
            plateBody: null,
            regionCode: 0,
        };
    }
    val storage = loading.parseInitialized();
    return {
        initialized: true,
        identityKey: storage.identityKey,
        collectionAddress: storage.collectionAddress,
        ownerAddress: storage.ownerAddress,
        plateBody: storage.plateBody,
        regionCode: storage.regionCode,
    };
}

get fun get_auction_info(): PlateAuctionState? {
    val loading = startLoadingPlateItemStorage();
    if (!loading.isInitialized()) {
        return null;
    }
    val storage = loading.parseInitialized();
    if (storage.auction == null) {
        return null;
    }
    return storage.auction!.load();
}

get fun get_expiration_time(): uint64 {
    val loading = startLoadingPlateItemStorage();
    assert (loading.isInitialized()) throw 794;
    val storage = loading.parseInitialized();
    return storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
}

get fun get_last_renewal_time(): uint64 {
    val loading = startLoadingPlateItemStorage();
    assert (loading.isInitialized()) throw 794;
    val storage = loading.parseInitialized();
    return storage.lastRenewalTime;
}

