export function node_url(networkName: string): string {
  const uri = process.env[networkName.toUpperCase() + "_RPC_URL"];
  if (uri && uri !== "") {
    return uri;
  } else {
    return "";
  }
}

export function verifyKey(scannerName: string) {
  const apiKey = process.env[scannerName.toUpperCase() + "_API_KEY"];
  if (apiKey && apiKey !== "") {
    return apiKey;
  } else {
    return "";
  }
}

export function getMnemonic(networkName?: string): string {
  if (networkName) {
    const mnemonic = process.env["MNEMONIC_" + networkName.toUpperCase()];
    if (mnemonic && mnemonic !== "") {
      return mnemonic;
    }
  }

  return "test test test test test test test test test test test junk";
}

export function accounts(networkName?: string): { mnemonic: string } {
  return { mnemonic: getMnemonic(networkName) };
}
