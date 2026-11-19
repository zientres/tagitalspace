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

type AllowedPlateItemMessage = PlateItemBid | SettlePlateAuction

fun onInternalMessage(in: InMessage) {
    val loading = startLoadingPlateItemStorage();

    if (!loading.isInitialized()) {
        val uninitialized = loading.parseNotInitialized();
        assert (in.senderAddress == uninitialized.collectionAddress) throw 775;

        val init = lazy PlateItemInitData.fromSlice(in.body);
        val initialAuction = PlateAuctionState {
            highestBidder: init.firstBidder,
            highestBid: in.valueCoins,
            auctionEndTime: blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION,
        };
        val storage = PlateItemStorageInitialized {
            identityKey: uninitialized.identityKey,
            collectionAddress: uninitialized.collectionAddress,
            plateBody: init.plateBody,
            regionCode: init.regionCode,
            collectionOwner: init.collectionOwner,
            developmentSecurityFund: init.developmentSecurityFund,
            ownerAddress: null,
            auction: initialAuction.toCell(),
        };
        storage.save();
        return;
    }

    var storage = loading.parseInitialized();
    assert (in.senderAddress != storage.collectionAddress || in.body.isEmpty()) throw 776;

    if (in.body.isEmpty() || in.body.preloadUint(32) == 0) {
        val unpacked = storage.unpackAuction();
        assert (!unpacked.0) throw 777;
        var auction = unpacked.1;
        tagitalSpaceProcessPlateBid(in.senderAddress, in.valueCoins, mutate storage, mutate auction);
        return;
    }

    val msg = lazy AllowedPlateItemMessage.fromSlice(in.body);
    match (msg) {
        PlateItemBid => {
            val unpacked = storage.unpackAuction();
            assert (!unpacked.0) throw 777;
            var auction = unpacked.1;
            tagitalSpaceProcessPlateBid(in.senderAddress, in.valueCoins, mutate storage, mutate auction);
        }
        SettlePlateAuction => {
            val unpacked = storage.unpackAuction();
            assert (!unpacked.0) throw 778;
            tagitalSpaceSettlePlateAuction(mutate storage, unpacked.1, msg.queryId);
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
