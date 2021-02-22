/*
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.5.6;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract KIP7Storage is Ownable {
    uint256 private totalSupply;
    string private name;
    string private symbol;
    uint8 private decimals;
    //keccak256('TYPE_MINTER')
    bytes32 public constant TYPE_MINTER = 0xa8791d3acb7f4f152c41f3308e90b16e68a23666347d9c4c5ce8535dffead10d;
    //keccak256('TYPE_BURNER')
    bytes32 public constant TYPE_BURNER = 0x9a433df5d818859975655002918d19fe2ba4567432e52f0cec8426ddf4dc2ada;

    mapping(bytes4 => bool) private _supportedInterfaces;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    function updateBalance(address target, uint256 amount) external onlyOwner {
        _balances[target] = amount;
    }

    function updateAllowance(address owner, address spender, uint256 amount) external onlyOwner {
        _allowances[owner][spender] = amount;
    }

    function updateTotalSupply(uint256 input) external onlyOwner {
        totalSupply = input;
    }

    function updateTokenDetails(string calldata inputName, string calldata inputSymbol, uint8 inputDecimals) external onlyOwner {
        name = inputName;
        symbol = inputSymbol;
        decimals = inputDecimals;
    }

    function updateSupportedInterfaces(bytes4 interfaceId) external onlyOwner {
        require(interfaceId != 0xffffffff, 'KIP13: invalid interface id');
        _supportedInterfaces[interfaceId] = true;
    }

    function getName() external view returns (string memory) {
        return name;
    }

    function getSymbol() external view returns (string memory) {
        return symbol;
    }

    function getDecimals() external view returns (uint8) {
        return decimals;
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    function getBalance(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getAllowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function getSupportedInterfaces(bytes4 interfaceId) external view returns (bool) {
        return _supportedInterfaces[interfaceId];
    }
}
