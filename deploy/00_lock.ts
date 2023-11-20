import { DeployFunction } from "hardhat-deploy/types";
import { Ship, getTime } from "../utils";
import { Lock__factory } from "../types";

const func: DeployFunction = async (hre) => {
  const { deploy } = await Ship.init(hre);

  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const ONE_GWEI = "1000000000";

  const lockedAmount = ONE_GWEI;
  const unlockTime = (await getTime()) + ONE_YEAR_IN_SECS;

  await deploy(Lock__factory, {
    args: [unlockTime],
    value: lockedAmount,
  });
};

export default func;
func.tags = ["lock"];
