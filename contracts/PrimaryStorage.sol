/*
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.5.6;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract PrimaryStorage is Ownable {
    //keccak256('TYPE_OPERATOR');
    bytes32 public constant TYPE_OPERATOR = 0x9fcbc028a398b1c2b359b09bbe9cc6a31f9bdb6608fee74a6b53dedeeed8bb8f;
    address logicContract;
    string version;

    function setLogicContract(address newLogicContract, string calldata newVersion) external onlyOwner {
        logicContract = newLogicContract;
        version = newVersion;
    }

    function getLogicAddr() external view returns (address) {
        return logicContract;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }
}
