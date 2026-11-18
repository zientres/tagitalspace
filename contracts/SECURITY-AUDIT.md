# Pre-deployment security review

Date: 2026-11-18  
Repository reviewed: `zientres/tagitalspace`, branch `main`.

## Scope and conclusion

This review covers the files currently committed to this repository. It is **not** a contract security audit and does not certify deployability. The repository currently contains TON DNS reference contracts, two TagitalSpace helper modules, JSON specification vectors, and the website. It does not contain the TagitalSpace registry, auction manager, treasury, NFT collection deployment implementation, or the browser registry client.

**Conclusion: do not deploy a TagitalSpace collection from this repository yet.** The missing project-specific on-chain implementation prevents meaningful end-to-end or adversarial contract testing.

## Findings

### Critical — no deployable TagitalSpace contract system

The current tree has no TagitalSpace registry/auction-manager contracts, no treasury distribution contract, and no deployable collection/item implementation. The TON DNS reference contracts are not substitutes: they use domain hashes and TON DNS ownership/release semantics, not plate-plus-region identity and TagitalSpace economics.

Required before deployment:
- enforce uniqueness on the pair `(canonical_plate, region_code)`;
- calculate the agreed starting price from the six-character plate body;
- allow any wallet to create an auction by making the first bid;
- enforce the TON DNS minimum bid rule (at least 5% above the previous bid);
- use a one-hour initial auction and restore a full hour when a bid arrives with less than one hour remaining;
- settle winner/minting and handle failed/bounced deployment safely;
- distribute proceeds 50% to the owner, 30% to treasury retained by the contract, and 20% to the configured development/security wallet;
- implement the agreed yearly owner renewal/expiry behavior;
- prevent double settlement, duplicate minting, replay, and unauthorized treasury withdrawals.

### Critical — frontend registry client is missing

`From/Russia/Russia.html` references `registry-client.js`, but that file is not present in the committed repository tree. The page therefore has no committed implementation for the lookup/start-auction/place-bid methods it calls. Wallet connection alone is not contract integration.

### High — no reproducible Tolk build/test project is committed

There is no committed Acton project configuration, deployment configuration, contract test suite, or CI workflow in the current tree. The JSON vectors are specifications; they do not compile or execute the Tolk modules.

### High — TON DNS reference code must remain reference-only

The vendor Tolk files are now synchronized with the official `ton-blockchain/acton-contracts` DNS Tolk sources, with the auction start duration adapted to one hour. They preserve DNS-specific storage, messages, domain hashing, DNS governance, and release behavior. They must not be deployed as TagitalSpace contracts without a separate, reviewed adaptation.

### Resolved in this review — stale auction copy and timing vectors

- Website copy no longer claims a 90-minute auction or a fixed 1 TON opening bid.
- The Russia page displays a one-hour initial duration.
- The timing helper and vectors use a one-hour duration and cover the exact-end-time boundary.
- Plate-pricing and auction-timing vectors pass the independent JavaScript verifier added alongside this report.

## Verification limits

The independent vector verifier checks the agreed arithmetic/specification only. It does not compile Tolk, execute TVM transactions, test bounce handling, validate message serialization, or prove contract safety. Those checks remain mandatory in Codespaces before any collection deployment.
