import { DeployFunction } from "hardhat-deploy/types";
import { keccak256, solidityPackedKeccak256, toUtf8Bytes } from "ethers";

const func: DeployFunction = async (hre) => {
  const a = keccak256(toUtf8Bytes("juris.storage.escrow"));
  const b = solidityPackedKeccak256(["uint256"], [a]);
  console.log(a, b);
};

export default func;
func.tags = ["test"];
