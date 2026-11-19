// TagitalSpace auction policy.
// Monetary values are denominated in nanotons.

const TAGITALSPACE_AUCTION_DURATION = 3600;
const TAGITALSPACE_AUCTION_EXTENSION_WINDOW = 3600;
const TAGITALSPACE_MINIMUM_BID_NUMERATOR = 105;
const TAGITALSPACE_MINIMUM_BID_DENOMINATOR = 100;

// First bid must cover the plate's configured starting price.
fun tagitalSpaceValidateFirstBid(attachedValue: coins, startingPrice: coins): bool {
    return startingPrice > 0 && attachedValue >= startingPrice;
}

// Subsequent bid threshold uses floor(currentBid * 105 / 100),
// matching TON DNS integer rounding.
fun tagitalSpaceMinimumNextBid(currentBid: coins): coins {
    assert (currentBid > 0) throw 720;
    return currentBid * TAGITALSPACE_MINIMUM_BID_NUMERATOR
        / TAGITALSPACE_MINIMUM_BID_DENOMINATOR;
}

fun tagitalSpaceValidateNextBid(attachedValue: coins, currentBid: coins): bool {
    return attachedValue >= tagitalSpaceMinimumNextBid(currentBid);
}

fun tagitalSpaceInitialAuctionEndTime(now: int): int {
    return now + TAGITALSPACE_AUCTION_DURATION;
}

// A bid extends the deadline only when strictly less than one hour remains.
// Exactly 3600 seconds remaining does not extend the auction.
fun tagitalSpacePolicyAuctionEndTimeAfterBid(now: int, auctionEndTime: int): int {
    assert (auctionEndTime >= now) throw 721;

    if (auctionEndTime - now < TAGITALSPACE_AUCTION_EXTENSION_WINDOW) {
        return now + TAGITALSPACE_AUCTION_EXTENSION_WINDOW;
    }
    return auctionEndTime;
}

// Keep the same strict deadline comparison used by the TON DNS reference:
// settlement becomes available only when now is greater than end time.
fun tagitalSpaceIsAuctionFinished(now: int, auctionEndTime: int): bool {
    return now > auctionEndTime;
}
