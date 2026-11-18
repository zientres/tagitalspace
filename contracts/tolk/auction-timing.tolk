// TagitalSpace auction timing policy.
// Initial duration: 90 minutes.
// A bid with less than one hour remaining resets the deadline to now + 1 hour.

const TAGITALSPACE_AUCTION_INITIAL_DURATION = 5_400;
const TAGITALSPACE_AUCTION_EXTENSION_WINDOW = 3_600;

fun tagitalSpaceAuctionEndTimeAfterBid(currentTime: int, auctionEndTime: int): int {
    assert (auctionEndTime > currentTime) throw 702;

    val remaining = auctionEndTime - currentTime;
    if (remaining < TAGITALSPACE_AUCTION_EXTENSION_WINDOW) {
        return currentTime + TAGITALSPACE_AUCTION_EXTENSION_WINDOW;
    }
    return auctionEndTime;
}
