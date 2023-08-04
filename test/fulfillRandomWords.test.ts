import { deployContract } from "./utils";
import {MoonrunnersLoot, VRFCoordinatorV2Mock, WeaponToBlood} from "../typechain-types";
import { expect } from "chai";
import {address} from "hardhat/internal/core/config/config-validation";
import { ethers } from "hardhat";

describe('fulfillRandomWords', () => {
	it('should assign correct rarity for ', async () => {
		const vrfContract = await deployContract(
			"VRFCoordinatorV2Mock",
			[0, 0]
		) as VRFCoordinatorV2Mock;
		const lootContract = await deployContract("MoonrunnersLoot") as MoonrunnersLoot;
		await vrfContract.createSubscription();
		await vrfContract.fundSubscription(1, ethers.parseEther("7"));
		const weaponToBloodContract = await deployContract(
			"WeaponToBlood",
			[1, lootContract.getAddress()]
		) as WeaponToBlood;
		await vrfContract.addConsumer(1, weaponToBloodContract.getAddress());
		// await vrfContract.fulfillRandomWords()
		console.log('0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007');
	});
});