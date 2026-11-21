import "../wrappers/TagitalSpacePlateItem.gen"
import "../.acton/emulation/config"
import "../.acton/emulation/network"
import "../.acton/emulation/testing"
import "../.acton/testing/expect"
import "../contracts/tolk/plate-identity"
import "../contracts/tolk/plate-item-messages"
import "../contracts/tolk/registry-messages"

fun testPlateIdentityKey(): uint256 {
    return tagitalSpaceBuildPlateIdentity("A123BC".beginParse(), 77).hash();
}

fun setupTest(): (
    TagitalSpacePlateItem,
    Treasury,
    Treasury,
    Treasury,
    Treasury,
    Treasury,
) {
    val collection = testing.treasury("collection");
    val firstBidder = testing.treasury("first-bidder");
    val secondBidder = testing.treasury("second-bidder");
    val thirdBidder = testing.treasury("third-bidder");
    val revenue = testing.treasury("revenue");

    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: testPlateIdentityKey(),
        collectionAddress: collection.address,
    });

    val initMessage = createMessage({
        bounce: false,
        value: grams("3.2"),
        dest: { workchain: contract.address.getWorkchain(), stateInit: contract.stateInit! },
        body: PlateItemInitData {
            firstBidder: firstBidder.address,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "A123BC",
            regionCode: 77,
            auctionRevenueAddress: revenue.address,
        },
    });

    val deployResult = net.send(collection.address, initMessage);
    expect(deployResult).toHaveSuccessfulDeploy({ to: contract.address });

    return (
        contract,
        collection,
        firstBidder,
        secondBidder,
        thirdBidder,
        revenue,
    );
}

get fun `test bid refund auction extension and payout`() {
    val (
        contract,
        collection,
        firstBidder,
        secondBidder,
        thirdBidder,
        revenue,
    ) = setupTest();

    val initialAuction = contract.getAuctionInfo();
    expect(initialAuction).toBeNotNull();
    val originalEndTime = initialAuction!.auctionEndTime;

    // At exactly 3600 seconds remaining, the deadline must not extend.
    val secondBid = contract.sendPlateItemBid(
        secondBidder.address,
        1,
        grams("3.15"),
        { value: grams("3.3") },
    );

    expect(secondBid).toHaveSuccessfulTx({ to: contract.address });
    expect(secondBid).toHaveTx({
        to: firstBidder.address,
        value: grams("3"),
    });

    val auctionAfterSecondBid = contract.getAuctionInfo()!;
    expect(auctionAfterSecondBid.auctionEndTime).toEqual(originalEndTime);

    // With less than 3600 seconds remaining, the next bid extends the auction.
    testing.setNow((testing.getNow() + 1) as uint32);

    val thirdBid = contract.sendPlateItemBid(
        thirdBidder.address,
        2,
        grams("3.31"),
        { value: grams("3.5") },
    );

    expect(thirdBid).toHaveSuccessfulTx({ to: contract.address });
    expect(thirdBid).toHaveTx({
        to: secondBidder.address,
        value: grams("3.15"),
    });

    val extendedAuction = contract.getAuctionInfo()!;
    expect(extendedAuction.highestBid).toEqual(grams("3.31"));
    expect(extendedAuction.highestBidder).toEqual(thirdBidder.address);
    expect(extendedAuction.auctionEndTime).toEqual(
        (testing.getNow() as uint64) + 3600,
    );

    // Settlement is allowed only after the deadline.
    testing.setNow((extendedAuction.auctionEndTime + 1) as uint32);

    val settlement = contract.sendSettlePlateAuction(
        collection.address,
        3,
        { value: grams("0.1") },
    );

    expect(settlement).toHaveSuccessfulTx({ to: contract.address });
    expect(settlement).toHaveTx({
        to: revenue.address,
        value: grams("3.31"),
    });

    expect(contract.getAuctionInfo()).toBeNull();

    val nftData = contract.getNftData();
    expect(nftData.ownerAddress).toBeNotNull();
    expect(nftData.ownerAddress!).toEqual(thirdBidder.address);
}

get fun `test bid below minimum is rejected`() {
    val (
        contract,
        _,
        _,
        secondBidder,
        _,
        _,
    ) = setupTest();

    val result = contract.sendPlateItemBid(
        secondBidder.address,
        1,
        grams("3.14"),
        { value: grams("3.3") },
    );

    expect(result).toHaveFailedTx({
        to: contract.address,
        exitCode: 771,
    });

    val auction = contract.getAuctionInfo()!;
    expect(auction.highestBid).toEqual(grams("3"));
}

get fun `test settlement deadline boundaries`() {
    val (
        contract,
        collection,
        _,
        _,
        _,
        revenue,
    ) = setupTest();
    val auction = contract.getAuctionInfo()!;
    val deadline = auction.auctionEndTime;

    // One second before the deadline: settlement must fail.
    testing.setNow((deadline - 1) as uint32);
    val beforeDeadline = contract.sendSettlePlateAuction(
        collection.address,
        10,
        { value: grams("0.1") },
    );
    expect(beforeDeadline).toHaveFailedTx({
        to: contract.address,
        exitCode: 773,
    });

    // Exactly at the deadline: settlement must still fail.
    testing.setNow(deadline as uint32);
    val atDeadline = contract.sendSettlePlateAuction(
        collection.address,
        11,
        { value: grams("0.1") },
    );
    expect(atDeadline).toHaveFailedTx({
        to: contract.address,
        exitCode: 773,
    });

    // One second after the deadline: settlement must succeed.
    testing.setNow((deadline + 1) as uint32);
    val afterDeadline = contract.sendSettlePlateAuction(
        collection.address,
        12,
        { value: grams("0.1") },
    );
    expect(afterDeadline).toHaveSuccessfulTx({ to: contract.address });
    expect(afterDeadline).toHaveTx({
        to: revenue.address,
        value: grams("3"),
    });
    expect(contract.getAuctionInfo()).toBeNull();
}

get fun `test bounced revenue payout becomes claimable`() {
    val collection = testing.treasury("bounce-collection");
    val firstBidder = testing.treasury("bounce-first-bidder");
    val revenueAddress = randomAddress("missing-revenue");

    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: testPlateIdentityKey(),
        collectionAddress: collection.address,
    });

    val initMessage = createMessage({
        bounce: false,
        value: grams("3.5"),
        dest: { workchain: contract.address.getWorkchain(), stateInit: contract.stateInit! },
        body: PlateItemInitData {
            firstBidder: firstBidder.address,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "A123BC",
            regionCode: 77,
            auctionRevenueAddress: revenueAddress,
        },
    });

    val deployResult = net.send(collection.address, initMessage);
    expect(deployResult).toHaveSuccessfulDeploy({ to: contract.address });

    var config = testing.getConfig();
    var prices = config.getMsgForwardPrices(BASECHAIN);
    prices.lumpPrice += 180_000_000;
    config.setMsgForwardPrices(prices, BASECHAIN);
    expect(testing.setConfig(config)).toEqual(true);

    val auction = contract.getAuctionInfo()!;
    testing.setNow((auction.auctionEndTime + 1) as uint32);

    // The destination is an uninitialized address, so the RichBounce payout
    // must return to the item and be recorded as a claimable liability.
    val settlement = contract.sendSettlePlateAuction(
        collection.address,
        20,
        { value: grams("0.5") },
    );

    expect(settlement).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getAuctionInfo()).toBeNull();
    expect(contract.getClaimablePayout()).toEqual(grams("3"));
    expect(testing.getAccountBalance(contract.address) >= grams("3.1")).toEqual(true);
}

get fun `test failed retry restores claimable payout`() {
    val collection = testing.treasury("retry-collection");
    val firstBidder = testing.treasury("retry-first-bidder");
    val revenueAddress = randomAddress("retry-missing-revenue");

    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: testPlateIdentityKey(),
        collectionAddress: collection.address,
    });

    val initMessage = createMessage({
        bounce: false,
        value: grams("3.2"),
        dest: { workchain: contract.address.getWorkchain(), stateInit: contract.stateInit! },
        body: PlateItemInitData {
            firstBidder: firstBidder.address,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "A123BC",
            regionCode: 77,
            auctionRevenueAddress: revenueAddress,
        },
    });

    val deployResult = net.send(collection.address, initMessage);
    expect(deployResult).toHaveSuccessfulDeploy({ to: contract.address });

    val auction = contract.getAuctionInfo()!;
    testing.setNow((auction.auctionEndTime + 1) as uint32);

    val settlement = contract.sendSettlePlateAuction(
        collection.address,
        30,
        { value: grams("0.1") },
    );
    expect(settlement).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getClaimablePayout()).toEqual(grams("3"));

    // Retrying to the same unavailable destination must bounce again.
    // The cleared liability must be restored by the second RichBounce.
    val retry = contract.sendRetryPlateItemPayout(
        collection.address,
        31,
        { value: grams("0.1") },
    );

    expect(retry).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getClaimablePayout()).toEqual(grams("3"));

    // A second consecutive failed retry must restore the same full liability.
    val secondRetry = contract.sendRetryPlateItemPayout(
        collection.address,
        32,
        { value: grams("0.1") },
    );
    expect(secondRetry).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getClaimablePayout()).toEqual(grams("3"));
}

get fun `test forged bounce with mismatched amount is rejected`() {
    val (
        contract,
        _,
        _,
        _,
        _,
        revenue,
    ) = setupTest();

    val originalBody = PlateItemRevenuePayout {
        queryId: 40,
        amount: grams("4"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val forgedBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };

    val forgedBounce = createMessage({
        bounce: false,
        value: grams("0.1"),
        dest: contract.address,
        body: forgedBody,
    }).bounced();

    val _result = testing.processSingleTraceStep(revenue.address, forgedBounce);
    // A forged bounce must not create a claimable liability.
    expect(contract.getClaimablePayout()).toEqual(0);
}

get fun `test bounce from unexpected sender is rejected`() {
    val (
        contract,
        _,
        _,
        _,
        _,
        _revenue,
    ) = setupTest();
    val attacker = testing.treasury("bounce-attacker");

    val originalBody = PlateItemRevenuePayout {
        queryId: 41,
        amount: grams("3"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val forgedBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };

    val forgedBounce = createMessage({
        bounce: false,
        value: grams("0.1"),
        dest: contract.address,
        body: forgedBody,
    }).bounced();

    testing.processSingleTraceStep(attacker.address, forgedBounce);
    // A bounce from any address other than the immutable revenue destination
    // must not create a claimable liability.
    expect(contract.getClaimablePayout()).toEqual(0);
}

get fun `test bounced outbid refund becomes claimable`() {
    val collection = testing.treasury("refund-bounce-collection");
    val unavailableBidder = randomAddress("refund-bounce-unavailable-bidder");
    val nextBidder = testing.treasury("refund-bounce-next-bidder");
    val revenue = testing.treasury("refund-bounce-revenue");

    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: testPlateIdentityKey(),
        collectionAddress: collection.address,
    });
    val initMessage = createMessage({
        bounce: false,
        value: grams("3.5"),
        dest: { workchain: contract.address.getWorkchain(), stateInit: contract.stateInit! },
        body: PlateItemInitData {
            firstBidder: unavailableBidder,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "A123BC",
            regionCode: 77,
            auctionRevenueAddress: revenue.address,
        },
    });
    val deployed = net.send(collection.address, initMessage);
    expect(deployed).toHaveSuccessfulDeploy({ to: contract.address });

    var config = testing.getConfig();
    var prices = config.getMsgForwardPrices(BASECHAIN);
    prices.lumpPrice += 180_000_000;
    config.setMsgForwardPrices(prices, BASECHAIN);
    expect(testing.setConfig(config)).toEqual(true);

    val nextBid = contract.sendPlateItemBid(
        nextBidder.address,
        40,
        grams("3.15"),
        { value: grams("3.6") },
    );

    expect(nextBid).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getClaimableRefund(unavailableBidder)).toEqual(grams("3"));
    expect(contract.getClaimableRefundTotal()).toEqual(grams("3"));
    expect(contract.getAuctionInfo()!.highestBidder).toEqual(nextBidder.address);

    // The unavailable bidder attempts to claim while its address is still
    // uninitialized. The outgoing refund bounces and must restore the liability.
    val failedClaim = contract.sendClaimPlateItemRefund(
        unavailableBidder,
        41,
        { value: grams("0.5") },
    );
    expect(failedClaim).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getClaimableRefund(unavailableBidder)).toEqual(grams("3"));
    expect(contract.getClaimableRefundTotal()).toEqual(grams("3"));
    expect(
        testing.getAccountBalance(contract.address) >= grams("3.15") + grams("3") + grams("0.1"),
    ).toEqual(true);
}

get fun `test original bidder can claim a bounced refund`() {
    val (
        contract,
        _,
        firstBidder,
        secondBidder,
        thirdBidder,
        _,
    ) = setupTest();

    // Seed the claim through a bounced message from the same address that
    // received the original refund. The value is actually attached to the test
    // transaction, so the claim cannot create an unfunded liability.
    val originalBody = PlateItemBidRefund {
        queryId: 50,
        recipient: firstBidder.address,
        amount: grams("3"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val bounceBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };
    val bouncedMessage = createMessage({
        bounce: false,
        value: grams("3"),
        dest: contract.address,
        body: bounceBody,
    }).bounced();

    testing.processSingleTraceStep(firstBidder.address, bouncedMessage);
    expect(contract.getClaimableRefund(firstBidder.address)).toEqual(grams("3"));

    // A second bidder's liability must remain isolated in the address-keyed map.
    val secondOriginalBody = PlateItemBidRefund {
        queryId: 52,
        recipient: secondBidder.address,
        amount: grams("4"),
    }.toCell();
    val secondOriginalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("4"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 2,
        createdAt: testing.getNow(),
    }.toCell();
    val secondBounceBody = RichBounceBody {
        originalBody: secondOriginalBody,
        originalInfo: secondOriginalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };
    val secondBouncedMessage = createMessage({
        bounce: false,
        value: grams("4"),
        dest: contract.address,
        body: secondBounceBody,
    }).bounced();
    testing.processSingleTraceStep(secondBidder.address, secondBouncedMessage);
    expect(contract.getClaimableRefund(secondBidder.address)).toEqual(grams("4"));
    expect(contract.getClaimableRefundTotal()).toEqual(grams("7"));

    val unauthorizedClaim = contract.sendClaimPlateItemRefund(
        thirdBidder.address,
        50,
        { value: grams("0.1") },
    );
    expect(unauthorizedClaim).toHaveFailedTx({
        to: contract.address,
        exitCode: 800,
    });
    expect(contract.getClaimableRefund(firstBidder.address)).toEqual(grams("3"));

    val claim = contract.sendClaimPlateItemRefund(
        firstBidder.address,
        51,
        { value: grams("0.1") },
    );

    expect(claim).toHaveSuccessfulTx({ to: contract.address });
    expect(claim).toHaveTx({
        to: firstBidder.address,
        value: grams("3"),
    });
    expect(contract.getClaimableRefund(firstBidder.address)).toEqual(0);
    expect(contract.getClaimableRefund(secondBidder.address)).toEqual(grams("4"));
    expect(contract.getClaimableRefundTotal()).toEqual(grams("4"));

    val secondClaim = contract.sendClaimPlateItemRefund(
        secondBidder.address,
        53,
        { value: grams("0.1") },
    );
    expect(secondClaim).toHaveSuccessfulTx({ to: contract.address });
    expect(secondClaim).toHaveTx({
        to: secondBidder.address,
        value: grams("4"),
    });
    expect(contract.getClaimableRefund(secondBidder.address)).toEqual(0);
    expect(contract.getClaimableRefundTotal()).toEqual(0);
}

get fun `test bounced refund with mismatched amount is rejected`() {
    val (
        contract,
        _,
        firstBidder,
        _,
        _,
        _,
    ) = setupTest();

    val originalBody = PlateItemBidRefund {
        queryId: 60,
        recipient: firstBidder.address,
        amount: grams("4"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val forgedBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };
    val forgedBounce = createMessage({
        bounce: false,
        value: grams("3"),
        dest: contract.address,
        body: forgedBody,
    }).bounced();

    testing.processSingleTraceStep(firstBidder.address, forgedBounce);
    expect(contract.getClaimableRefund(firstBidder.address)).toEqual(0);
    expect(contract.getClaimableRefundTotal()).toEqual(0);
}

get fun `test bounced refund from unexpected sender is rejected`() {
    val (
        contract,
        _,
        firstBidder,
        _,
        _,
        _,
    ) = setupTest();
    val attacker = testing.treasury("refund-bounce-attacker");

    val originalBody = PlateItemBidRefund {
        queryId: 61,
        recipient: firstBidder.address,
        amount: grams("3"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val forgedBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };
    val forgedBounce = createMessage({
        bounce: false,
        value: grams("3"),
        dest: contract.address,
        body: forgedBody,
    }).bounced();

    testing.processSingleTraceStep(attacker.address, forgedBounce);
    expect(contract.getClaimableRefund(firstBidder.address)).toEqual(0);
    expect(contract.getClaimableRefundTotal()).toEqual(0);
}

get fun `test only the current owner can renew and renewal extends one year`() {
    val (
        contract,
        collection,
        owner,
        secondBidder,
        _,
        _,
    ) = setupTest();
    val auction = contract.getAuctionInfo()!;
    testing.setNow((auction.auctionEndTime + 1) as uint32);

    val settlement = contract.sendSettlePlateAuction(
        collection.address,
        70,
        { value: grams("0.1") },
    );
    expect(settlement).toHaveSuccessfulTx({ to: contract.address });

    val originalExpiration = contract.getExpirationTime();
    val unauthorizedRenewal = contract.sendRenewPlateOwnership(
        secondBidder.address,
        71,
        { value: grams("0.05") },
    );
    expect(unauthorizedRenewal).toHaveFailedTx({
        to: contract.address,
        exitCode: 797,
    });

    testing.setNow((originalExpiration - 1) as uint32);
    val renewal = contract.sendRenewPlateOwnership(
        owner.address,
        72,
        { value: grams("0.05") },
    );
    expect(renewal).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getExpirationTime()).toEqual(
        (testing.getNow() as uint64) + 365 * 24 * 60 * 60,
    );

    val renewedExpiration = contract.getExpirationTime();
    testing.setNow(renewedExpiration as uint32);
    val atExpiration = contract.sendRenewPlateOwnership(
        owner.address,
        73,
        { value: grams("0.05") },
    );
    expect(atExpiration).toHaveFailedTx({
        to: contract.address,
        exitCode: 798,
    });
}

get fun `test only the owner can transfer plate ownership`() {
    val (
        contract,
        collection,
        owner,
        secondBidder,
        thirdBidder,
        _,
    ) = setupTest();
    val auction = contract.getAuctionInfo()!;
    testing.setNow((auction.auctionEndTime + 1) as uint32);

    val settlement = contract.sendSettlePlateAuction(
        collection.address,
        80,
        { value: grams("0.1") },
    );
    expect(settlement).toHaveSuccessfulTx({ to: contract.address });

    val unauthorizedTransfer = contract.sendTransferPlateOwnership(
        secondBidder.address,
        81,
        thirdBidder.address,
        { value: grams("0.05") },
    );
    expect(unauthorizedTransfer).toHaveFailedTx({
        to: contract.address,
        exitCode: 792,
    });

    val transfer = contract.sendTransferPlateOwnership(
        owner.address,
        82,
        secondBidder.address,
        { value: grams("0.05") },
    );
    expect(transfer).toHaveSuccessfulTx({ to: contract.address });
    expect(contract.getNftData().ownerAddress!).toEqual(secondBidder.address);
    expect(contract.getExpirationTime()).toEqual(
        (testing.getNow() as uint64) + 365 * 24 * 60 * 60,
    );
}

get fun `test payout bounce cannot create a liability larger than returned value plus fee buffer`() {
    val (
        contract,
        _,
        _,
        _,
        _,
        revenue,
    ) = setupTest();

    val originalBody = PlateItemRevenuePayout {
        queryId: 90,
        amount: grams("3"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val forgedBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };
    val forgedBounce = createMessage({
        bounce: false,
        value: grams("1"),
        dest: contract.address,
        body: forgedBody,
    }).bounced();

    testing.processSingleTraceStep(revenue.address, forgedBounce);
    expect(contract.getClaimablePayout()).toEqual(0);
}

get fun `test refund bounce cannot create a liability larger than returned value plus fee buffer`() {
    val (
        contract,
        _,
        firstBidder,
        _,
        _,
        _,
    ) = setupTest();

    val originalBody = PlateItemBidRefund {
        queryId: 91,
        recipient: firstBidder.address,
        amount: grams("3"),
    }.toCell();
    val originalInfo = RichBounceOriginalMsgInfo {
        valueCoins: grams("3"),
        valueExtra: createMapFromLowLevelDict<int32, varuint32>(null),
        createdLt: 1,
        createdAt: testing.getNow(),
    }.toCell();
    val forgedBody = RichBounceBody {
        originalBody,
        originalInfo,
        bouncedByPhase: 1,
        exitCode: 1,
        computePhase: null,
    };
    val forgedBounce = createMessage({
        bounce: false,
        value: grams("1"),
        dest: contract.address,
        body: forgedBody,
    }).bounced();

    testing.processSingleTraceStep(firstBidder.address, forgedBounce);
    expect(contract.getClaimableRefund(firstBidder.address)).toEqual(0);
    expect(contract.getClaimableRefundTotal()).toEqual(0);
}

get fun `test item rejects initialization with a mismatched deterministic identity`() {
    val collection = testing.treasury("identity-check-collection");
    val bidder = testing.treasury("identity-check-bidder");
    val revenue = testing.treasury("identity-check-revenue");
    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: testPlateIdentityKey(),
        collectionAddress: collection.address,
    });

    val initMessage = createMessage({
        bounce: false,
        value: grams("3.2"),
        dest: { workchain: contract.address.getWorkchain(), stateInit: contract.stateInit! },
        body: PlateItemInitData {
            firstBidder: bidder.address,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "B123BC",
            regionCode: 77,
            auctionRevenueAddress: revenue.address,
        },
    });
    val result = net.send(collection.address, initMessage);
    expect(result).toHaveFailedTx({
        to: contract.address,
        exitCode: 808,
    });
}

get fun `test item rejects initialization with a forged starting price`() {
    val collection = testing.treasury("price-check-collection");
    val bidder = testing.treasury("price-check-bidder");
    val revenue = testing.treasury("price-check-revenue");
    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: testPlateIdentityKey(),
        collectionAddress: collection.address,
    });

    val initMessage = createMessage({
        bounce: false,
        value: grams("3.2"),
        dest: { workchain: contract.address.getWorkchain(), stateInit: contract.stateInit! },
        body: PlateItemInitData {
            firstBidder: bidder.address,
            nftIndex: 0,
            firstBidAmount: grams("2.9"),
            plateBody: "A123BC",
            regionCode: 77,
            auctionRevenueAddress: revenue.address,
        },
    });
    val result = net.send(collection.address, initMessage);
    expect(result).toHaveFailedTx({
        to: contract.address,
        exitCode: 809,
    });
}

get fun `test expired item rejects changes to immutable identity and payout destination`() {
    val (
        contract,
        collection,
        _,
        _,
        _,
        revenue,
    ) = setupTest();
    val auction = contract.getAuctionInfo()!;
    testing.setNow((auction.auctionEndTime + 1) as uint32);
    val settlement = contract.sendSettlePlateAuction(
        collection.address,
        100,
        { value: grams("0.1") },
    );
    expect(settlement).toHaveSuccessfulTx({ to: contract.address });
    testing.setNow(contract.getExpirationTime() as uint32);

    val alteredIdentity = contract.sendAny(
        collection.address,
        PlateItemInitData {
            firstBidder: collection.address,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "B123BC",
            regionCode: 77,
            auctionRevenueAddress: revenue.address,
        }.toCell(),
        { value: grams("3.2") },
    );
    expect(alteredIdentity).toHaveFailedTx({
        to: contract.address,
        exitCode: 804,
    });

    val otherRevenue = testing.treasury("altered-revenue-destination");
    val alteredRevenue = contract.sendAny(
        collection.address,
        PlateItemInitData {
            firstBidder: collection.address,
            nftIndex: 0,
            firstBidAmount: grams("3"),
            plateBody: "A123BC",
            regionCode: 77,
            auctionRevenueAddress: otherRevenue.address,
        }.toCell(),
        { value: grams("3.2") },
    );
    expect(alteredRevenue).toHaveFailedTx({
        to: contract.address,
        exitCode: 804,
    });
    expect(contract.getAuctionInfo()).toBeNull();
    expect(contract.getNftData().ownerAddress).toBeNotNull();
}
