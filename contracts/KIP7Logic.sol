/*
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.5.6;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'caver-js/packages/caver-kct/src/contract/token/KIP7/IKIP7.sol';
import 'caver-js/packages/caver-kct/src/contract/token/KIP7/IKIP7Receiver.sol';
import './KIP7Storage.sol';
import './AccessControl.sol';
import './Pausable.sol';

contract KIP7Logic is AccessControl, Pausable, IKIP7 {
    using SafeMath for uint256;
    address public primaryStorage;
    address[] public additionalStorages;

    bytes4 private constant _INTERFACE_ID_IKIP7         = 0x65787371;
    bytes4 private constant _INTERFACE_ID_IKIP7METADATA = 0xa219a025;
    bytes4 private constant _INTERFACE_ID_IKIP13        = 0x01ffc9a7;
    bytes4 private constant _INTERFACE_ID_MINT          = 0x40c10f19;
    bytes4 private constant _INTERFACE_ID_PAUSE         = 0xe78a39d8;
    bytes4 private constant _KIP7_RECEIVED              = 0x9d188c22;

    function initialize() public {
        KIP7Storage(additionalStorages[0]).updateSupportedInterfaces(_INTERFACE_ID_IKIP7);
        KIP7Storage(additionalStorages[0]).updateSupportedInterfaces(_INTERFACE_ID_IKIP7METADATA);
        KIP7Storage(additionalStorages[0]).updateSupportedInterfaces(_INTERFACE_ID_IKIP13);
        KIP7Storage(additionalStorages[0]).updateSupportedInterfaces(_INTERFACE_ID_MINT);
        KIP7Storage(additionalStorages[0]).updateSupportedInterfaces(_INTERFACE_ID_PAUSE);
    }

    // KIP13
    /**
     * @dev See `IKIP13.supportsInterface`.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return KIP7Storage(additionalStorages[0]).getSupportedInterfaces(interfaceId);
    }

    // KIP7
    /**
     * @dev See `IKIP7.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return KIP7Storage(additionalStorages[0]).getTotalSupply();
    }

    /**
     * @dev See `IKIP7.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return KIP7Storage(additionalStorages[0]).getBalance(account);
    }

    /**
     * @dev See `IKIP7.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See `IKIP7.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return KIP7Storage(additionalStorages[0]).getAllowance(owner, spender);
    }

    /**
     * @dev See `IKIP7.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, value);
        return true;
    }

    /**
     * @dev See `IKIP7.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the KIP. See the note at the beginning of `KIP7`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 allowances = KIP7Storage(additionalStorages[0]).getAllowance(sender, _msgSender());
        _approve(sender, _msgSender(), allowances.sub(amount, 'KIP7: transfer amount exceeds allowance'));
        return true;
    }

    /**
    * @dev  Moves `amount` tokens from the caller's account to `recipient`.
    */
    function safeTransfer(address recipient, uint256 amount) public {
        safeTransfer(recipient, amount, '');
    }

    /**
    * @dev Moves `amount` tokens from the caller's account to `recipient`.
    */
    function safeTransfer(address recipient, uint256 amount, bytes memory data) public {
        transfer(recipient, amount);
        require(_checkOnKIP7Received(_msgSender(), recipient, amount, data), 'KIP7: transfer to non KIP7Receiver implementer');
    }

    /**
    * @dev Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    * `amount` is then deducted from the caller's allowance.
    */
    function safeTransferFrom(address sender, address recipient, uint256 amount) public {
        safeTransferFrom(sender, recipient, amount, '');
    }

    /**
    * @dev Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism.
    * `amount` is then deducted from the caller's allowance.
    */
    function safeTransferFrom(address sender, address recipient, uint256 amount, bytes memory data) public {
        transferFrom(sender, recipient, amount);
        require(_checkOnKIP7Received(sender, recipient, amount, data), 'KIP7: transfer to non KIP7Receiver implementer');
    }

    // KIP7Metadata
    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return KIP7Storage(additionalStorages[0]).getName();
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return KIP7Storage(additionalStorages[0]).getSymbol();
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * > Note that this information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `IKIP7.balanceOf` and `IKIP7.transfer`.
     */
    function decimals() public view returns (uint8) {
        return KIP7Storage(additionalStorages[0]).getDecimals();
    }

    // KIP7Mintable
    /**
     * @dev See `KIP7._mint`.
     */
    function mint(address account, uint256 amount) public returns (bool) {
        require(hasRole(KIP7Storage(additionalStorages[0]).TYPE_MINTER(), _msgSender()), 'Caller is not the Minter');
        _mint(account, amount);
        return true;
    }

    function mintMultiple(address[] calldata account, uint256[] calldata amount) external returns (bool) {
        for(uint256 i = 0; i < account.length; i++) {
            mint(account[i], amount[i]);
        }
    }

    // Specific function for Point swapping
    function burn(address targetAccount, uint256 amount) external returns (bool) {
        require(hasRole(KIP7Storage(additionalStorages[0]).TYPE_BURNER(), _msgSender()), 'Caller is not the Burner');
        _burn(targetAccount, amount);
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), 'KIP7: transfer from the zero address');
        require(recipient != address(0), 'KIP7: transfer to the zero address');

        uint256 senderBalance = KIP7Storage(additionalStorages[0]).getBalance(sender);
        uint256 recipientBalance = KIP7Storage(additionalStorages[0]).getBalance(recipient);
        senderBalance = senderBalance.sub(amount, 'KIP7: transfer amount exceeds balance');
        recipientBalance = recipientBalance.add(amount);
        KIP7Storage(additionalStorages[0]).updateBalance(sender, senderBalance);
        KIP7Storage(additionalStorages[0]).updateBalance(recipient, recipientBalance);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), 'KIP7: mint to the zero address');
        require(amount != 0, 'KIP7: Can not mint zero amount');

        uint256 currentTotalSupply = KIP7Storage(additionalStorages[0]).getTotalSupply();
        uint256 targetBalance = KIP7Storage(additionalStorages[0]).getBalance(account);

        currentTotalSupply = currentTotalSupply.add(amount);
        targetBalance = targetBalance.add(amount);

        KIP7Storage(additionalStorages[0]).updateTotalSupply(currentTotalSupply);
        KIP7Storage(additionalStorages[0]).updateBalance(account, targetBalance);

        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), 'KIP7: burn from the zero address');
        require(value != 0, 'KIP7: Can not burn zero amount');

        uint256 currentTotalSupply = KIP7Storage(additionalStorages[0]).getTotalSupply();
        uint256 targetBalance = KIP7Storage(additionalStorages[0]).getBalance(account);

        targetBalance = targetBalance.sub(value, 'KIP7: burn amount exceeds balance');
        currentTotalSupply = currentTotalSupply.sub(value);

        KIP7Storage(additionalStorages[0]).updateTotalSupply(currentTotalSupply);
        KIP7Storage(additionalStorages[0]).updateBalance(account, targetBalance);

        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), 'KIP7: approve from the zero address');
        require(spender != address(0), 'KIP7: approve to the zero address');

        KIP7Storage(additionalStorages[0]).updateAllowance(owner, spender, value);
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        uint256 allowances = KIP7Storage(additionalStorages[0]).getAllowance(account, _msgSender());
        _approve(account, _msgSender(), allowances.sub(amount));
    }

    /**
     * @dev Internal function to invoke `onKIP7Received` on a target address.
     * The call is not executed if the target address is not a contract.
     */
    function _checkOnKIP7Received(address sender, address recipient, uint256 amount, bytes memory _data)
        internal returns (bool)
    {
        uint256 size = 0;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(recipient) }

        if (size == 0) {
            return true;
        }

        bytes4 retval = IKIP7Receiver(recipient).onKIP7Received(_msgSender(), sender, amount, _data);
        return (retval == _KIP7_RECEIVED);
    }
}
