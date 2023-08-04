// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

interface ILoot {
    function controlledBurn(address _from, uint256 _id, uint256 _amount) external;

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external;
}

contract WeaponToBlood is VRFConsumerBaseV2 {
    address lootContract;
    mapping(uint256 => uint256[]) weaponToRarityChances;
    struct ChainlinkRequest {
        address sender;
        uint256[] weaponIds;
    }
    mapping(uint256 => ChainlinkRequest) requests;
    address owner;
    uint256 price = 0;
    event RandomBloodMinted(address user, uint256[] bloodIds);

    // Chainlink
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    address vrfCoordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
    bytes32 keyHash = 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805;
    uint32 callbackGasLimit = 300000;
    uint16 requestConfirmations = 3;

    constructor(uint64 _subscriptionId, address _lootContract) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        owner = msg.sender;
        subscriptionId = _subscriptionId;
        lootContract = _lootContract;
        weaponToRarityChances[0] = [0, 530, 975, 1000]; // Raygun: 0, 530, 445, 25
        weaponToRarityChances[8] = [360, 910, 1000, 1000]; // Katana: 360, 550, 90, 0
        weaponToRarityChances[1] = [510, 950, 1000, 1000]; // Scroll: 510, 440, 50, 0
        weaponToRarityChances[2] = [660, 970, 1000, 1000]; // AR15: 660, 310, 30, 0
        weaponToRarityChances[9] = [660, 970, 1000, 1000]; // Moon Staff: 660, 310, 30, 0
        weaponToRarityChances[3] = [770, 990, 1000, 1000]; // Claws: 770, 220, 10, 0
    }

    function setLootContract(address _lootContract) public onlyOwner {
        lootContract = _lootContract;
    }

    function setSubscriptionId(uint64 _subscriptionId) public onlyOwner {
        subscriptionId = _subscriptionId;
    }

    function setCallbackGasLimit(uint32 _callbackGasLimit) public onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    function setRequestConfirmations(uint16 _requestConfirmations) public onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function checkIsWeapon(uint256 weaponId) private pure {
        require(
            weaponId == 3 || weaponId == 2 || weaponId == 9 || weaponId == 8 || weaponId == 1 || weaponId == 0,
            "Item is not a Weapon!"
        );
    }

    function burnWeaponsForRandomBlood(
        uint256[] memory _weaponIds
    ) public payable {
        require(msg.value >= price, "Not enough ETH sent!");
        for (uint256 i = 0; i < _weaponIds.length; i++) {
            uint256 weaponId = _weaponIds[i];
            checkIsWeapon(weaponId);
            ILoot(lootContract).controlledBurn(msg.sender, weaponId, 1);
        }
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        requests[requestId].weaponIds = _weaponIds;
        requests[requestId].sender = msg.sender;
    }

    function getBloodRarity(uint256 weaponId, uint256 randomNum) private view returns (uint256) {
        uint256[] memory rarities = weaponToRarityChances[weaponId];
        for (uint256 i = 0; i < rarities.length; i++) {
            if (randomNum < rarities[i]) {
                if (i == 0) {
                    return 7; // common blood (Almanazar)
                } else if (i == 1) {
                    return 6; // rare blood (Balthazar)
                } else if (i == 2) {
                    return 5; // epic blood (Nebuchadnezzar)
                } else if (i == 3) {
                    return 4; // legendary blood (Melchizedek)
                }
            }
        }
        return 7; // common blood (Almanazar)
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256[] memory weaponIds = requests[requestId].weaponIds;
        uint256 randomNum = randomWords[0];
        uint256[] memory bloodIds = new uint256[](weaponIds.length);
        uint256[] memory amounts = new uint256[](weaponIds.length);
        for (uint256 i = 0; i < weaponIds.length; i++) {
            uint256 randomRarityChance = (randomNum % (1000 ** (i+1))) / (1000 ** i);
            uint256 bloodId = getBloodRarity(weaponIds[i], randomRarityChance);
            bloodIds[i] = bloodId;
            amounts[i] = 1;
        }
        ILoot(lootContract).mintBatch(requests[requestId].sender, bloodIds, amounts);
        emit RandomBloodMinted(requests[requestId].sender, bloodIds);
    }

    function burnWeaponsForBlood(uint256[] memory _weaponIds) public {
        uint256[] memory bloodIds = new uint256[](_weaponIds.length);
        uint256[] memory amounts = new uint256[](_weaponIds.length);
        for (uint256 i = 0; i < _weaponIds.length; i++) {
            uint256 weaponId = _weaponIds[i];
            checkIsWeapon(weaponId);
            ILoot(lootContract).controlledBurn(msg.sender, _weaponIds[i], 1);
            if (weaponId == 3 || weaponId == 2 || weaponId == 9) { // claw or AR15 or Moon Staff
                bloodIds[i] = 7; // small blood
            } else if (weaponId == 8 || weaponId == 1) { // Katana or Scroll
                bloodIds[i] = 6; // medium blood
            } else if (weaponId == 0) { // Raygun
                bloodIds[i] = 5; // large blood
            }
            amounts[i] = 1;
        }
        ILoot(lootContract).mintBatch(msg.sender, bloodIds, amounts);
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function withdrawEth() public onlyOwner {
        (bool sent,) = payable(owner).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}
