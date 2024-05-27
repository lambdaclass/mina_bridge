export function stringifyWithBigInt(input: any) {
    return JSON.stringify(input, (_key, value) => typeof value === "bigint" ? value.toString() : value);
}
