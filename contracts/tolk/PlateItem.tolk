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

type AllowedPlateItemMessage = PlateItemBid | SettlePlateAuction | ClaimPlatePayout | RenewPlateOwnership | TransferPlateOwnership

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
            pendingOwnerPayout: 0,
            pendingTreasuryPayout: 0,
            pendingSecurityPayout: 0,
            lastRenewalTime: blockchain.now(),
        };
        storage.save();
        return;
    }

    var storage = loading.parseInitialized();

    // Registry can restart an expired identity, but never overwrite a live
    // auction or erase unsettled payout liabilities.
    if (in.senderAddress == storage.collectionAddress && (in.body.isEmpty() || in.body.preloadUint(32) != 0x54531004)) {
        val init = lazy PlateItemInitData.fromSlice(in.body);
        val expirationTime = storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
        val isExpired = storage.ownerAddress != null
            && storage.auction == null
            && blockchain.now() >= expirationTime;
        val hasUnpaidLiabilities = storage.pendingOwnerPayout > 0
            || storage.pendingTreasuryPayout > 0
            || storage.pendingSecurityPayout > 0;

        if (isExpired && !hasUnpaidLiabilities) {
            storage.ownerAddress = null;
            storage.collectionOwner = init.collectionOwner;
            storage.developmentSecurityFund = init.developmentSecurityFund;
            storage.plateBody = init.plateBody;
            storage.regionCode = init.regionCode;
            storage.lastRenewalTime = blockchain.now();
            storage.auction = PlateAuctionState {
                highestBidder: init.firstBidder,
                highestBid: in.valueCoins,
                auctionEndTime: blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION,
            }.toCell();
            storage.save();
            return;
        }

        // Duplicate requests, active items, and expired items with unpaid
        // proceeds are rejected by returning the incoming bid to its sender.
        val refund = createMessage({
            bounce: false,
            dest: init.firstBidder,
            value: 0,
            body: PlateItemExcesses { queryId: blockchain.logicalTime() as uint64 },
        });
        refund.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        return;
    }

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
        RenewPlateOwnership => {
            tagitalSpaceRenewPlateOwnership(in.senderAddress, mutate storage);
        }
        ClaimPlatePayout => {
            assert (storage.auction == null) throw 787;
            tagitalSpaceClaimPlatePayout(
                in.senderAddress,
                msg.queryId,
                msg.beneficiaryKind,
                mutate storage,
            );
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

get fun get_pending_payouts(): (coins, coins, coins) {
    val loading = startLoadingPlateItemStorage();
    assert (loading.isInitialized()) throw 788;
    val storage = loading.parseInitialized();
    return (
        storage.pendingOwnerPayout,
        storage.pendingTreasuryPayout,
        storage.pendingSecurityPayout,
    );
}
