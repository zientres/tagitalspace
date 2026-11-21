import "registry-messages"
import "registry-state"
import "registry-storage"

const TAGITALSPACE_REGISTRY_MIN_STORAGE = grams("0.05")
const TAGITALSPACE_REGISTRY_REFUND_FEE_BUFFER = grams("0.05")

fun tagitalSpaceRegistryRecordClaimableRefund(
    recipient: address,
    amount: coins,
    mutate storage: TagitalSpaceRegistryStorage,
) {
    assert (amount > 0) throw 740;
    var refunds = storage.claimableRefunds;
    val previous = refunds.get(recipient);
    var claimableAmount = amount;
    if (previous.isFound) {
        claimableAmount += previous.loadValue();
    }
    refunds.set(recipient, claimableAmount);
    storage.claimableRefunds = refunds;
    storage.claimableRefundTotal += amount;
}

fun tagitalSpaceClaimRegistryRefund(
    senderAddress: address,
    queryId: uint64,
) {
    var storage = TagitalSpaceRegistryStorage.load();
    var refunds = storage.claimableRefunds;
    val lookup = refunds.get(senderAddress);
    assert (lookup.isFound) throw 741;
    val amount = lookup.loadValue();
    assert (amount > 0) throw 741;
    assert (storage.claimableRefundTotal >= amount) throw 741;

    // getOriginalBalance already includes the inbound claim message value.
    assert (
        contract.getOriginalBalance() >=
        storage.claimableRefundTotal + TAGITALSPACE_REGISTRY_MIN_STORAGE +
        TAGITALSPACE_REGISTRY_REFUND_FEE_BUFFER
    ) throw 742;

    refunds.delete(senderAddress);
    storage.claimableRefunds = refunds;
    storage.claimableRefundTotal -= amount;
    storage.save();

    val refund = createMessage({
        bounce: BounceMode.RichBounce,
        dest: senderAddress,
        value: amount,
        body: RegistryRefund {
            queryId,
            recipient: senderAddress,
            amount,
        },
    });
    refund.send(SEND_MODE_PAY_FEES_SEPARATELY);
}
