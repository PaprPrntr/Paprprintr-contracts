// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract DoubleOwnable is Context {
    address private _primaryOwner;
    address private _secondaryOwner;

    event PrimaryOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SecondaryOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () public {
        address msgSender = _msgSender();
        _primaryOwner = msgSender;
        emit PrimaryOwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current primary owner.
     */
    function primaryOwner() public view virtual returns (address) {
        return _primaryOwner;
    }

    /**
     * @dev Returns the address of the current secondary owner.
     */
    function secondaryOwner() public view virtual returns (address) {
        return _secondaryOwner;
    }

    /**
     * @dev Throws if called by any account other than the primary owner.
     */
    modifier onlyPrimaryOwner() {
        require(primaryOwner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Throws if called by any account other than the both owners.
     */
    modifier onlyOwner() {
        require(primaryOwner() == _msgSender() || secondaryOwner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyPrimaryOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyPrimaryOwner {
        emit PrimaryOwnershipTransferred(_primaryOwner, address(0));
        _primaryOwner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferPrimaryOwnership(address newOwner) public virtual onlyPrimaryOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit PrimaryOwnershipTransferred(_primaryOwner, newOwner);
        _primaryOwner = newOwner;
    }

    /**
     * @dev Set secondary ownership of the contract to a new account (`newOwner`).
     * Can only be called by the primary owner.
     */

    function setSecondaryOwnership(address newOwner) public virtual onlyPrimaryOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit SecondaryOwnershipTransferred(_secondaryOwner, newOwner);
        _secondaryOwner = newOwner;
    }
}