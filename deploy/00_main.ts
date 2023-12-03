import { DeployFunction } from "hardhat-deploy/types";
import { Ship } from "../utils";
import {
  InitFacet__factory,
  JUSDC__factory,
  JurisEscrowFactoryFacet__factory,
  JurisPoolFacet__factory,
  JurisEscrow__factory,
} from "../types";

const func: DeployFunction = async (hre) => {
  const { deploy, deployDiamond } = await Ship.init(hre);

  const jusdc = await deploy(JUSDC__factory);

  const escrowImplementation = await deploy(JurisEscrow__factory);

  await deployDiamond(
    "JurisFund",
    [InitFacet__factory, JurisPoolFacet__factory, JurisEscrowFactoryFacet__factory],
    InitFacet__factory,
    "init",
    [jusdc.address, 2 * 365 * 24 * 3600, 10000000n, escrowImplementation.address],
  );
};

export default func;
func.tags = ["init"];
