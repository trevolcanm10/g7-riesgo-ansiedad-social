/** Repair the known UTF-8-as-Latin-1 sequences from old recommendation imports. */
export function decodeLegacyRecommendation(value: string): string {
  return value.replace(/Ã[\u0080-\u00BF]/g, (pair) =>
    Buffer.from(pair, "latin1").toString("utf8"),
  );
}
