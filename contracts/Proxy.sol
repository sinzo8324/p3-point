/*
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.5.6;

import './Pausable.sol';
import './AccessControl.sol';
import './PrimaryStorage.sol';

contract Proxy is AccessControl, Pausable {
    address public primaryStorage;
    address[] public additionalStorages;

    modifier onlyOperator() {
        require(hasRole(PrimaryStorage(primaryStorage).TYPE_OPERATOR(), _msgSender()), 'Caller is not the Operator');
        _;
    }

    constructor (address primaryStorageAddress) public {
        primaryStorage = primaryStorageAddress;
        bytes32 typeOperator = PrimaryStorage(primaryStorage).TYPE_OPERATOR();
        _setRoleAdmin(typeOperator, typeOperator);
        _setupRole(typeOperator, _msgSender());

    }

    function () external {
        address _impl = PrimaryStorage(primaryStorage).getLogicAddr();
        require(_impl != address(0), 'Logic contract has not been registed yet');

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function addAdditionalStorage(address storageContractAddress) external onlyOperator {
        additionalStorages.push(storageContractAddress);
    }

    function updateAdditionalStorage(uint256 index, address storageContractAddress) external onlyOperator {
        additionalStorages[index] = storageContractAddress;
    }

    function updateLogicContract(address logicContract, string calldata version) external onlyOperator {
        PrimaryStorage(primaryStorage).setLogicContract(logicContract, version);
    }

    function transferStorageOwnership(uint256 index, address target) external onlyOperator {
        Ownable(additionalStorages[index]).transferOwnership(target);
    }

    function addRoleType(bytes32 role) external onlyOperator {
        _setRoleAdmin(role, PrimaryStorage(primaryStorage).TYPE_OPERATOR());
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    function getStorageList() external view returns (address[] memory) {
        return additionalStorages;
    }
}
