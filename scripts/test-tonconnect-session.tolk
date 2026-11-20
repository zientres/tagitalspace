import "../.acton/io"
import "../.acton/prompts"
import "../.acton/emulation/scripts"

/// Checks TON Connect session establishment only. Does not send a transaction.
fun main() {
    val wallet = scripts.wallet(promptWallet("Select the Testnet diagnostic wallet:"));
    println("TON Connect session established.");
    println("Connected wallet: {}", wallet.address);
    println("No transaction was created or sent.");
}
