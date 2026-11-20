(() => {
    const config = window.TAGITALSPACE_REGISTRY_CONFIG || {};
    let runtimePromise = null;
    let clientPromise = null;

    const NANOTON = 1_000_000_000n;
    const START_AUCTION_BUFFER = 150_000_000n;
    const BID_BUFFER = 100_000_000n;
    const MIN_BID_PERCENT = 105n;

    function loadRuntime() {
        if (!runtimePromise) {
            runtimePromise = import("https://esm.sh/@ton/ton@15.1.0?bundle").then((ton) => {
                if (!ton.TonClient || !ton.Address || !ton.beginCell || !ton.TupleBuilder) {
                    throw new Error("Не удалось загрузить TON SDK.");
                }
                return ton;
            });
        }
        return runtimePromise;
    }

    async function getClientContext() {
        if (!config.registryAddress) {
            throw new Error("Адрес Registry ещё не настроен. Сначала разверните контракт в Testnet и укажите его адрес в registry-config.js.");
        }

        if (!clientPromise) {
            clientPromise = loadRuntime().then(({ TonClient, Address }) => {
                const options = { endpoint: config.endpoint };
                if (config.apiKey) options.apiKey = config.apiKey;
                return {
                    client: new TonClient(options),
                    registryAddress: Address.parse(config.registryAddress),
                    Address,
                };
            });
        }
        return clientPromise;
    }

    function transliterate(value) {
        const map = {
            А: "A", В: "B", Е: "E", К: "K", М: "M", Н: "H",
            О: "O", Р: "P", С: "C", Т: "T", У: "Y", Х: "X",
        };
        return value.toUpperCase().replace(/[АВЕКМНОРСТУХ]/g, (letter) => map[letter] || letter);
    }

    function parsePlate(value) {
        const normalized = transliterate(String(value || "").replace(/\s+/g, ""));
        const match = normalized.match(/^([ABEKMHOPCTYX][0-9]{3}[ABEKMHOPCTYX]{2})([0-9]{2,3})$/);
        if (!match) {
            throw new Error("Введите номер в формате А123ВС77 или А123ВС777.");
        }
        return {
            plateBody: match[1],
            regionCode: Number(match[2]),
        };
    }

    function parseTonAmount(value) {
        const normalized = String(value).trim().replace(",", ".");
        if (!/^[0-9]+(?:\.[0-9]{1,9})?$/.test(normalized)) {
            throw new Error("Введите корректную сумму в TON.");
        }
        const [whole, fraction = ""] = normalized.split(".");
        return BigInt(whole) * NANOTON + BigInt((fraction + "000000000").slice(0, 9));
    }

    function toBase64(bytes) {
        let binary = "";
        for (let i = 0; i < bytes.length; i += 1) {
            binary += String.fromCharCode(bytes[i]);
        }
        return btoa(binary);
    }

    function friendlyAddress(address) {
        return address.toString({
            urlSafe: true,
            bounceable: true,
            testOnly: true,
        });
    }

    async function getPlateItemAddress(runtime, plateBody, regionCode) {
        const tuple = new runtime.TupleBuilder();
        tuple.writeString(plateBody);
        tuple.writeNumber(BigInt(regionCode));
        const result = await runtime.client.runMethod(
            runtime.registryAddress,
            "get_plate_item_address",
            tuple.build(),
        );
        return result.stack.readAddress();
    }

    async function getStartingPrice(runtime, plateBody) {
        const tuple = new runtime.TupleBuilder();
        tuple.writeString(plateBody);
        const result = await runtime.client.runMethod(
            runtime.registryAddress,
            "get_plate_starting_price",
            tuple.build(),
        );
        return result.stack.readBigNumber();
    }

    async function getPlateState(client, itemAddress) {
        const result = await client.runMethod(itemAddress, "get_plate_state");
        const stack = result.stack;
        return {
            status: stack.readNumber(),
            ownerAddress: stack.readAddressOpt(),
            highestBid: stack.readBigNumber(),
            endTime: stack.readNumber(),
            expirationTime: stack.readNumber(),
        };
    }

    function buildStartAuctionBody(runtime, plateBody, regionCode) {
        return runtime.beginCell()
            .storeUint(0x54530001, 32)
            .storeUint(BigInt(Date.now()), 64)
            .storeStringTail(plateBody)
            .storeUint(regionCode, 16)
            .endCell();
    }

    function buildBidBody(runtime, bidAmount) {
        return runtime.beginCell()
            .storeUint(0x00000000, 32)
            .storeUint(BigInt(Date.now()), 64)
            .storeCoins(bidAmount)
            .endCell();
    }

    async function sendWalletTransaction(runtime, destination, amount, body) {
        const tonConnect = window.tagitalSpaceTonConnect;
        if (!tonConnect || !tonConnect.connected) {
            throw new Error("Сначала подключите Keeper к TagitalSpace.");
        }
        if (tonConnect.account && tonConnect.account.chain && tonConnect.account.chain !== config.network) {
            throw new Error("Кошелёк подключён не к TON Testnet. Переключите сеть и подключитесь снова.");
        }

        return tonConnect.sendTransaction({
            validUntil: Math.floor(Date.now() / 1000) + 600,
            network: config.network || "-3",
            messages: [{
                address: typeof destination === "string" ? destination : friendlyAddress(destination),
                amount: amount.toString(),
                payload: toBase64(body.toBoc()),
            }],
        });
    }

    async function lookupRussianPlate(fullPlate) {
        const parsed = parsePlate(fullPlate);
        const runtime = await getClientContext();
        const [itemAddress, startingBid] = await Promise.all([
            getPlateItemAddress(runtime, parsed.plateBody, parsed.regionCode),
            getStartingPrice(runtime, parsed.plateBody),
        ]);
        const itemAddressText = friendlyAddress(itemAddress);
        const deployed = await runtime.client.isContractDeployed(itemAddress);

        if (!deployed) {
            return {
                status: "free",
                itemAddress: itemAddressText,
                startingBid,
            };
        }

        const state = await getPlateState(runtime.client, itemAddress);
        if (state.status === 0) {
            return {
                status: "free",
                itemAddress: itemAddressText,
                startingBid,
                expirationTime: state.expirationTime,
            };
        }

        if (state.status === 1 || state.status === 2) {
            const minimumNextBid = (state.highestBid * MIN_BID_PERCENT) / 100n;
            return {
                status: "auction",
                itemAddress: itemAddressText,
                auction: {
                    auctionId: itemAddressText,
                    status: state.status === 1 ? 0 : 1,
                    startingBid: state.highestBid,
                    highestBid: state.highestBid,
                    minimumBidStep: minimumNextBid - state.highestBid,
                    endTime: state.endTime,
                },
            };
        }

        if (state.status === 3) {
            return {
                status: "minted",
                itemAddress: itemAddressText,
                ownerAddress: state.ownerAddress ? friendlyAddress(state.ownerAddress) : null,
                expirationTime: state.expirationTime,
            };
        }

        throw new Error("Контракт номера вернул неизвестное состояние.");
    }

    async function startRussianAuctionWithFirstBid(fullPlate) {
        const parsed = parsePlate(fullPlate);
        const runtime = await getClientContext();
        const startingBid = await getStartingPrice(runtime, parsed.plateBody);
        const body = buildStartAuctionBody(runtime, parsed.plateBody, parsed.regionCode);
        const attachedValue = startingBid + START_AUCTION_BUFFER;
        return sendWalletTransaction(runtime, runtime.registryAddress, attachedValue, body);
    }

    async function placeBid(auctionId, amountTon) {
        const runtime = await getClientContext();
        const bidAmount = parseTonAmount(amountTon);
        const itemAddress = runtime.Address.parse(auctionId);
        const state = await getPlateState(runtime.client, itemAddress);
        if (state.status !== 1) {
            throw new Error("Аукцион уже завершён или номер больше не выставлен на торги.");
        }

        const minimumBid = (state.highestBid * MIN_BID_PERCENT) / 100n;
        if (bidAmount < minimumBid) {
            throw new Error("Минимальная следующая ставка: " + (Number(minimumBid) / Number(NANOTON)).toFixed(3) + " TON.");
        }

        const body = buildBidBody(runtime, bidAmount);
        return sendWalletTransaction(
            runtime,
            itemAddress,
            bidAmount + BID_BUFFER,
            body,
        );
    }

    window.tagitalSpaceRegistry = Object.freeze({
        lookupRussianPlate,
        startRussianAuctionWithFirstBid,
        placeBid,
    });
})();
