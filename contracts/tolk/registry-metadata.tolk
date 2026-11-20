fun tagitalSpaceBuildCollectionContent(): cell {
    var metadata: map<uint256, string> = [];
    metadata.set("name".sha256(), "TagitalSpace — Russia");
    metadata.set(
        "description".sha256(),
        "Digital Russian license plate collectibles from TagitalSpace.",
    );
    metadata.set(
        "image".sha256(),
        "https://zientres.github.io/tagitalspace/logo.png",
    );
    return beginCell()
        .storeUint(0, 8)
        .storeDict(metadata.toLowLevelDict())
        .endCell();
}
