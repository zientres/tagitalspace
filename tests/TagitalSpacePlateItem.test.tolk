import "@stdlib/gas-payments"
import "../.acton/emulation/network"
import "../.acton/emulation/testing"
import "../.acton/testing/expect"
import "../wrappers/TagitalSpacePlateItem.gen"
import "../contracts/tolk/plate-item-messages"
import "../contracts/tolk/registry-messages"

fun setupTest(): (TagitalSpacePlateItem, Treasury, Treasury, Treasury, Treasury, Treasury) {
    val collection = testing.treasury("collection");
    val firstBidder = testing.treasury("first-bidder");
    val secondBidder = testing.treasury("second-bidder");
    val thirdBidder = testing.treasury("third-bidder");
    val revenue = testing.treasury("revenue");

    val contract = TagitalSpacePlateItem.fromStorage({
        identityKey: 1,
        collectionAddress: collection.address,
    });

    val initMessage = createMessage({
        bounce: false,
        value: grams("3.2"),
        dest: {
            workchain: contract.address.getWorkchain(),
            stateInit: contract.stateInit!,
        },
        body: PlateItemInitData {
            firstBidder: firstBidder.address,
            firstBidAmount: grams("3"),
            plateBody: beginCell().storeString("A123BC").endCell(),
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
    val (contract, collection, firstBidder, secondBidder, thirdBidder, revenue) = setupTest();

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
    val (contract, _, _, secondBidder, _, _) = setupTest();

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
    val (contract, collection, _, _, _, revenue) = setupTest();
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
