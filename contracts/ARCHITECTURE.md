# TagitalSpace contract architecture

Status: implementation in progress; not deployable.
Network: TON Testnet only (network id -3).

## Contract model — TON DNS pattern

TagitalSpace follows the architecture of TON DNS:
- TagitalSpaceRegistry is the collection contract. It validates the plate and Russian region, derives a deterministic item address from the item code and identity, and deploys that item with the first bid.
- TagitalSpacePlateItem is a separate contract for each unique (plate body, region) pair. It stores that plate's auction state and handles later bids, outbid refunds, deadline extension, settlement and NFT ownership.
- There is no Auction Manager and no shared contract that stores or operates all auctions.
- The item address is deterministic from the identity key and Registry address, matching the DnsCollection / DnsItem StateInit pattern.
- Repeating a first-bid request for an existing item must not overwrite its auction; the initialized item returns the attached value to the new requester.

## Identity and uniqueness

- Canonical plate body is exactly six ASCII characters: letter, three digits, two letters, using A B E K M H O P C T Y X.
- Region is separate and validated against the Russia allowlist (212 supported codes; 20 excluded).
- Identity is (canonical plate body, region code). The same body may exist in another region.
- Starting price depends on the six-character body only.

## Auction policy

- Any wallet may start an auction by submitting the first bid through Registry.
- Starting price: base 3 TON; mirrored letters 15 TON; mirrored digits 15 TON; triples 50 TON; both blocks add; base applies only when no special pattern applies; triple does not stack with mirror pricing in its own block.
- Each item's first bid initializes its local auction state.
- Later bids must be at least floor(current bid × 105 / 100).
- Initial duration is 3,600 seconds. A bid with strictly less than 3,600 seconds remaining extends the deadline to now + 3,600; exactly 3,600 seconds does not extend.
- No bid history is stored.
- Anyone may trigger settlement after the deadline; the item contract persists the winner as owner and clears the auction once.

## Distribution

The winning bid is divided:
- 50% to the collection owner;
- 30% to the Registry treasury;
- 20% to the configured development/security fund.

The item contract is responsible for splitting its own auction proceeds. Registry records only treasury deposits; it does not manage bidder escrow or auction state. Settlement records three claimable payout balances in the item. The configured beneficiary claims their share; the Registry owner triggers the Registry's 30% claim. These claim transfers currently use non-bounceable messages, so bounced-transfer recovery is not implemented and action-phase behavior still requires TVM tests.

## NFT lifecycle

The per-plate item is itself the NFT item contract. Its deterministic StateInit includes the Registry address and identity key. Before settlement it reports no owner; after settlement the highest bidder becomes owner. Basic owner-authorized NFT transfer is implemented. Each item has a one-year ownership period measured from settlement (when the winner becomes owner), its last renewal, or ownership transfer. The current owner may renew before expiration; each successful renewal resets the one-year period from the renewal time. After expiration, the next valid first-bid request can restart the auction in the same deterministic item contract. Expiration does not start an auction by itself. Unpaid settlement liabilities remain stored in the item and accumulate across auctions; reauction does not erase prior claims. A separate renewal price has not been configured; renewal currently requires only the on-chain owner message and network fees.

## Required verification before deployment

1. Tolk compile, formatter and Acton build.
2. TVM tests for item deployment, duplicate identity, bid thresholds, deadline boundaries, refund accounting, settlement, payout bounce and treasury accounting.
3. StateInit/address derivation tests proving different regions produce different item addresses.
4. Testnet end-to-end auction with controlled wallets.
5. Independent security review of compiled contracts and deployment configuration.

JavaScript source checks and design notes are not proof of Tolk compilation, TVM correctness or security.
