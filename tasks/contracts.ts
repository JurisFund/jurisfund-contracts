import { task } from "hardhat/config";
import fs from "fs";
import path from "path";

task("contracts", "Get deployed contract's address").setAction(async (taskArgs, hre) => {
  const networkName = hre.network.name;
  const directory = `./deployments/${networkName}`;
  const files = fs.readdirSync(directory);
  const contractNames = files
    .filter((file: string) => {
      // get the details of the file
      const fileDetails = fs.lstatSync(path.resolve(directory, file));
      const extension = file.split(".")?.at(1) ?? "";
      // check if the file is directory
      if (fileDetails.isDirectory() || extension != "json") {
        return false;
      } else {
        return true;
      }
    })
    .map((file) => file.split(".")[0]);

  const contracts: string[] = [];
  for (const contractName of contractNames) {
    const artifacts = require(`../deployments/${networkName}/${contractName}.json`);
    const address = artifacts.address as string;
    contracts.push(`${contractName}: "${address}"`);
  }

  console.log(contracts.join(","));
});
