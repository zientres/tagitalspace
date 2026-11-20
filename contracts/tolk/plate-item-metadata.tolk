import "@stdlib/strings"

fun tagitalSpaceBuildPlateItemContent(
    plateBody: cell,
    regionCode: uint16,
): cell {
    val plate = plateBody as string;
    val region = regionCode as int;
    val name = StringBuilder.create()
        .append("TagitalSpace ")
        .append(plate)
        .append(" · ")
        .appendInt(region)
        .build();
    val description = StringBuilder.create()
        .append("Digital Russian license plate ")
        .append(plate)
        .append(" from region ")
        .appendInt(region)
        .append(", registered in TagitalSpace.")
        .build();
    val attributes = StringBuilder.create()
        .append("[{\"trait_type\":\"Country\",\"value\":\"Russia\"},")
        .append("{\"trait_type\":\"Plate\",\"value\":\"")
        .append(plate)
        .append("\"},{\"trait_type\":\"Region\",\"value\":\"")
        .appendInt(region)
        .append("\"}]")
        .build();
    val imageData = StringBuilder.create()
        .append("<svg xmlns='http://www.w3.org/2000/svg' width='720' height='240' viewBox='0 0 720 240'>")
        .append("<rect width='720' height='240' rx='28' fill='#f8fafc'/>")
        .append("<rect x='14' y='14' width='692' height='212' rx='20' fill='white' stroke='#111827' stroke-width='12'/>")
        .append("<rect x='34' y='34' width='18' height='172' fill='#ffffff'/>")
        .append("<rect x='52' y='34' width='18' height='172' fill='#2563eb'/>")
        .append("<rect x='70' y='34' width='18' height='172' fill='#dc2626'/>")
        .append("<text x='380' y='145' text-anchor='middle' font-family='Arial,sans-serif' font-size='94' font-weight='700' letter-spacing='5' fill='#111827'>")
        .append(plate)
        .append("</text>")
        .append("<text x='650' y='196' text-anchor='end' font-family='Arial,sans-serif' font-size='34' font-weight='700' fill='#111827'>")
        .appendInt(region)
        .append("</text>")
        .append("<text x='650' y='70' text-anchor='end' font-family='Arial,sans-serif' font-size='22' font-weight='700' fill='#111827'>RUS</text>")
        .append("</svg>")
        .build();

    var metadata: map<uint256, string> = [];
    metadata.set("name".sha256(), name);
    metadata.set("description".sha256(), description);
    metadata.set("attributes".sha256(), attributes);
    metadata.set("image_data".sha256(), imageData);

    return beginCell()
        .storeUint(0, 8)
        .storeDict(metadata.toLowLevelDict())
        .endCell();
}
