import "plate-identity"
import "plate-item-auction"
import "plate-item-messages"
import "plate-item-metadata"
import "plate-item-state"
import "plate-pricing"
import "registry-messages"
import "russia-regions"

contract TagitalSpacePlateItem {
    author: "TagitalSpace"
    version: "0.1.0"
    description: "Individual TagitalSpace plate NFT with its own auction"
    incomingMessages: AllowedPlateItemMessage
    storage: PlateItemStorageInitialized
    storageAtDeployment: PlateItemStorageNotInitialized
}

type AllowedPlateItemMessage =
    | PlateItemBid
    | SettlePlateAuction
    | RetryPlateItemPayout
    | ClaimPlateItemRefund
    | GetNftStaticData
    | RenewPlateOwnership
    | TransferPlateOwnership

fun onInternalMessage(in: InMessage) {
    if (!in.body.isEmpty() && in.body.preloadUint(32) == 0x5fcc3d14) {
        // TEP-62 read interface is exposed for indexing, but marketplace
        // transfers are intentionally disabled. Use TagitalSpace transfer flow.
        throw 805;
    }

    val loading = startLoadingPlateItemStorage();

    if (!loading.isInitialized()) {
        val uninitialized = loading.parseNotInitialized();
        assert (in.senderAddress == uninitialized.collectionAddress) throw 775;

        val init = lazy PlateItemInitData.fromSlice(in.body);
        val initPlate = init.plateBody.beginParse();
        assert (tagitalSpaceValidateRussiaRegionCode(init.regionCode as int)) throw 807;
        assert (
            tagitalSpaceBuildPlateIdentity(initPlate, init.regionCode as int).hash() ==
            uninitialized.identityKey
        ) throw 808;
        assert (tagitalSpacePlateStartPrice(initPlate) == init.firstBidAmount) throw 809;
        assert (init.auctionRevenueAddress.getWorkchain() == BASECHAIN) throw 810;
        assert (in.valueCoins >= init.firstBidAmount + TAGITALSPACE_ITEM_MIN_STORAGE) throw 776;
        val initialAuction = PlateAuctionState {
            highestBidder: init.firstBidder,
            highestBid: init.firstBidAmount,
            auctionEndTime: blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION,
        };
        val immutable = PlateItemImmutableData {
            identityKey: uninitialized.identityKey,
            nftIndex: init.nftIndex,
            collectionAddress: uninitialized.collectionAddress,
            plateBody: init.plateBody,
            regionCode: init.regionCode,
            auctionRevenueAddress: init.auctionRevenueAddress,
        };
        val storage = PlateItemStorageInitialized {
            immutable: immutable.toCell(),
            ownerAddress: null,
            auction: initialAuction.toCell(),
            lastRenewalTime: blockchain.now(),
            claimablePayout: 0,
            claimableRefunds: [],
            claimableRefundTotal: 0,
        };
        storage.save();
        return;
    }

    var storage = loading.parseInitialized();
    val immutable = storage.immutable.load();

    // Registry may restart an expired identity, but cannot overwrite a live
    // auction. Each completed auction pays its winning bid immediately.
    if (in.senderAddress == immutable.collectionAddress && in.body.preloadUint(32) == 0x54531006) {
        val init = lazy PlateItemInitData.fromSlice(in.body);
        assert (init.nftIndex == immutable.nftIndex) throw 804;
        val initPlate = init.plateBody.beginParse();
        assert (tagitalSpaceValidateRussiaRegionCode(init.regionCode as int)) throw 804;
        assert (
            tagitalSpaceBuildPlateIdentity(initPlate, init.regionCode as int).hash() ==
            immutable.identityKey
        ) throw 804;
        assert (tagitalSpacePlateStartPrice(initPlate) == init.firstBidAmount) throw 804;
        assert (init.auctionRevenueAddress == immutable.auctionRevenueAddress) throw 804;
        val expirationTime = storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
        val isExpired = storage.ownerAddress != null && storage.auction == null &&
            blockchain.now() >= expirationTime;
        // Reuse the deterministic item address for the next auction after expiry.
        if (isExpired) {
            storage.ownerAddress = null;
            // Keep the immutable revenue destination configured by the Registry.
            storage.lastRenewalTime = blockchain.now();
            assert (in.valueCoins >= init.firstBidAmount + TAGITALSPACE_ITEM_MIN_STORAGE) throw 776;
            // The new auction bid must not mask an underfunded payout or refund
            // liability left by the previous ownership period.
            assert (
                contract.getOriginalBalance() >=
                in.valueCoins + storage.claimablePayout + storage.claimableRefundTotal +
                TAGITALSPACE_ITEM_MIN_STORAGE
            ) throw 776;
            storage.auction = PlateAuctionState {
                highestBidder: init.firstBidder,
                highestBid: init.firstBidAmount,
                auctionEndTime: blockchain.now() + TAGITALSPACE_ITEM_AUCTION_DURATION,
            }.toCell();
            storage.save();
            return;
        }

        // Duplicate requests and active items are rejected by returning the
        // incoming bid to their sender.
        // Keep duplicate-request funds claimable in the item instead of
        // risking a non-bounceable transfer to a contract that rejects it.
        // The new refund liability must be fully backed without consuming the
        // active bid, earlier claims, or the minimum storage reserve.
        assert (
            contract.getOriginalBalance() >=
            tagitalSpaceItemActiveBidAmount(storage) + storage.claimablePayout +
            storage.claimableRefundTotal +
            in.valueCoins +
            TAGITALSPACE_ITEM_MIN_STORAGE
        ) throw 776;
        tagitalSpaceRecordClaimableRefund(
            init.firstBidder,
            in.valueCoins,
            mutate storage,
        );
        storage.save();
        return;
    }

    val msg = lazy AllowedPlateItemMessage.fromSlice(in.body);
    match (msg) {
        PlateItemBid => {
            val unpacked = storage.unpackAuction();
            assert (!unpacked.0) throw 777;
            tagitalSpaceProcessPlateBid(
                in.senderAddress,
                in.valueCoins,
                msg.bidAmount,
                mutate storage,
                unpacked.1,
            );
        }
        SettlePlateAuction => {
            val unpacked = storage.unpackAuction();
            assert (!unpacked.0) throw 778;
            tagitalSpaceSettlePlateAuction(
                mutate storage,
                unpacked.1,
                msg.queryId,
            );
        }
        RetryPlateItemPayout => {
            tagitalSpaceRetryPlatePayout(
                mutate storage,
                msg.queryId,
            );
        }
        ClaimPlateItemRefund => {
            tagitalSpaceClaimPlateItemRefund(
                in.senderAddress,
                mutate storage,
                msg.queryId,
            );
        }
        GetNftStaticData => {
            val response = createMessage({
                bounce: false,
                dest: in.senderAddress,
                value: 0,
                body: ReportNftStaticData {
                    queryId: msg.queryId,
                    index: immutable.nftIndex as uint256,
                    collectionAddress: immutable.collectionAddress,
                },
            });
            response.send(
                SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE + SEND_MODE_BOUNCE_ON_ACTION_FAIL,
            );
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

fun onBouncedMessage(in: InMessageBounced) {
    val rich = lazy RichBounceBody.fromSlice(in.bouncedBody);
    val originalBody = rich.originalBody.beginParse();
    val opcode = originalBody.preloadUint(32);

    if (opcode == 0x54531008) {
        val payout = lazy PlateItemRevenuePayout.fromSlice(rich.originalBody.beginParse());
        val originalInfo = rich.originalInfo.load();

        var storage = startLoadingPlateItemStorage().parseInitialized();
        val immutable = storage.immutable.load();

        // Only a bounced payout from the immutable revenue destination is recoverable here.
        assert (in.senderAddress == immutable.auctionRevenueAddress) throw 789;
        assert (payout.amount > 0) throw 789;

        // The payload amount must match the actual value of the bounced outgoing message.
        assert (payout.amount == originalInfo.valueCoins) throw 789;
        // Bounce fees depend on network configuration. Restore the full payout
        // only when the actual balance still covers every escrow and liability.
        assert (
            contract.getOriginalBalance() >=
            tagitalSpaceItemActiveBidAmount(storage) + storage.claimablePayout +
            storage.claimableRefundTotal +
            payout.amount +
            TAGITALSPACE_ITEM_MIN_STORAGE +
            TAGITALSPACE_ITEM_PAYOUT_FEE_BUFFER
        ) throw 789;

        storage.claimablePayout += payout.amount;
        storage.save();
        return;
    }

    if (opcode == 0x54531009) {
        val refund = lazy PlateItemBidRefund.fromSlice(rich.originalBody.beginParse());
        val originalInfo = rich.originalInfo.load();

        var storage = startLoadingPlateItemStorage().parseInitialized();

        // The original recipient is the only address allowed to own this refund claim.
        assert (in.senderAddress == refund.recipient) throw 799;
        assert (refund.amount > 0) throw 799;
        assert (refund.amount == originalInfo.valueCoins) throw 799;
        // Use the actual post-bounce balance instead of a fixed fee allowance.
        assert (
            contract.getOriginalBalance() >=
            tagitalSpaceItemActiveBidAmount(storage) + storage.claimablePayout +
            storage.claimableRefundTotal +
            refund.amount +
            TAGITALSPACE_ITEM_MIN_STORAGE +
            TAGITALSPACE_ITEM_REFUND_FEE_BUFFER
        ) throw 799;

        tagitalSpaceRecordClaimableRefund(
            refund.recipient,
            refund.amount,
            mutate storage,
        );
        storage.save();
        return;
    }

    throw 789;
}

get fun get_plate_data(): PlateItemNftData {
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
    val immutable = storage.immutable.load();
    return {
        initialized: true,
        identityKey: immutable.identityKey,
        collectionAddress: immutable.collectionAddress,
        ownerAddress: storage.ownerAddress,
        plateBody: immutable.plateBody,
        regionCode: immutable.regionCode,
    };
}

get fun get_nft_data(): (int, int, address, address?, cell) {
    val loading = startLoadingPlateItemStorage();
    if (!loading.isInitialized()) {
        val uninitialized = loading.parseNotInitialized();
        return (0, 0, uninitialized.collectionAddress, null, beginCell().endCell());
    }

    val storage = loading.parseInitialized();
    val immutable = storage.immutable.load();
    val expirationTime = storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
    val isOwned = storage.ownerAddress != null && blockchain.now() < expirationTime;
    var owner: address? = null;
    var initialized = 0;
    if (isOwned) {
        owner = storage.ownerAddress;
        initialized = 1;
    }
    val content = tagitalSpaceBuildPlateItemContent(
        immutable.plateBody,
        immutable.regionCode,
    );

    return (initialized, immutable.nftIndex as int, immutable.collectionAddress, owner, content);
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
    return storage.auction.load();
}

get fun get_plate_state(): (int, address?, coins, uint64, uint64) {
    val loading = startLoadingPlateItemStorage();
    if (!loading.isInitialized()) {
        return (0, null, 0, 0, 0);
    }

    val storage = loading.parseInitialized();
    val expirationTime = storage.lastRenewalTime + TAGITALSPACE_ITEM_OWNERSHIP_PERIOD;
    if (storage.auction != null) {
        val auction = storage.auction.load();
        if (blockchain.now() <= auction.auctionEndTime) {
            return (1, null, auction.highestBid, auction.auctionEndTime, expirationTime);
        }
        return (2, null, auction.highestBid, auction.auctionEndTime, expirationTime);
    }

    if (storage.ownerAddress != null && blockchain.now() < expirationTime) {
        return (3, storage.ownerAddress, 0, 0, expirationTime);
    }
    return (0, null, 0, 0, expirationTime);
}

get fun get_claimable_payout(): coins {
    val loading = startLoadingPlateItemStorage();
    assert (loading.isInitialized()) throw 794;
    val storage = loading.parseInitialized();
    return storage.claimablePayout;
}

get fun get_claimable_refund(ownerAddress: address): coins {
    val loading = startLoadingPlateItemStorage();
    assert (loading.isInitialized()) throw 794;
    val storage = loading.parseInitialized();
    val lookup = storage.claimableRefunds.get(ownerAddress);
    if (!lookup.isFound) {
        return 0;
    }
    return lookup.loadValue();
}

get fun get_claimable_refund_total(): coins {
    val loading = startLoadingPlateItemStorage();
    assert (loading.isInitialized()) throw 794;
    val storage = loading.parseInitialized();
    return storage.claimableRefundTotal;
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
