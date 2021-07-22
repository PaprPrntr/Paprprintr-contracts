
pragma solidity 0.6.12;

/**
 * This contract is the $PRNTR ERC20 token.
 * by PaprPrintr
 *
 * _____                     _____        _         _         
 *|  __ \                   |  __ \      (_)       | |        
 *| |__) |__ _  _ __   _ __ | |__) |_ __  _  _ __  | |_  _ __ 
 *|  ___// _  ||  _ \ |  __||  ___/|  __|| ||  _ \ | __||  __|
 *| |   | (_| || |_) || |   | |    | |   | || | | || |_ | |   
 *|_|    \__,_|| .__/ |_|   |_|    |_|   |_||_| |_| \__||_|   
 *             |_|                                         
 */

import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import './owner/DoubleOperator.sol';

/**
 * @title PRNTR base contract
 * @notice ..
 * @author PaprPrintr's team
 */

contract PRNTR is ERC20Burnable, DoubleOperator {

    /* ========== STATE VARIABLES ========== */

    //fees
    uint256 public feesTaxRate = 15;
    //list of addresses which exclude fees
    mapping(address => bool) public senderExcludedAddresses;
    mapping(address => bool) public recipientExcludedAddresses;
    uint256 public lockRatio = 50;
    // Liquidity
    address public injector;


    /* ========== CONSTRUCTOR ========== */

    constructor() public ERC20('PRNTR', 'PRNTR') {
        _mint(msg.sender, 100001 * 10**18);

    }

    /* ========== FEES ========== */

    // Check the mapping for excluded addresses with fees (Treasury/Boardroom)
    // ==> Fees do not apply to the core algorithm.
    function isSenderExcludedAddresses(address _address) public view returns(bool isIndeed) {
        return senderExcludedAddresses[_address];
    }


    // Add an address to the exluded mapping
    function addSenderExcludedAddresses(address newAddress) public onlyDoubleOperator returns(bool) {
        require(!isSenderExcludedAddresses(newAddress));
        senderExcludedAddresses[newAddress] = true;
        return true;
    }


    // Removes an address from the excluded mapping
    function removeSenderExcludedAddresses(address oldAddress) public onlyDoubleOperator returns(bool) {
        require(isSenderExcludedAddresses(oldAddress));
        senderExcludedAddresses[oldAddress] = false;
        return true;
    }

    //----------------- Recipient --------------------//

    function isRecipientExcludedAddresses(address _address) public view returns(bool isIndeed) {
        return recipientExcludedAddresses[_address];
    }


    // Add an address to the exluded mapping
    function addRecipientExcludedAddresses(address newAddress) public onlyDoubleOperator returns(bool) {
        require(!isRecipientExcludedAddresses(newAddress));
       recipientExcludedAddresses[newAddress] = true;
        return true;
    }


    // Removes an address from the excluded mapping
    function removeRecipientExcludedAddresses(address oldAddress) public onlyDoubleOperator returns(bool) {
        require(isRecipientExcludedAddresses(oldAddress));
        recipientExcludedAddresses[oldAddress] = false;
        return true;
    }

    //----------------- Recipient --------------------//

    // Set fees (index) :
    function setfeesTaxRate(uint256 fees) public onlyDoubleOperator {
        require(fees <= 45);
        feesTaxRate = fees;
    }

    function setfeesLockRate(uint256 _lockRatio) public onlyDoubleOperator {
        lockRatio = _lockRatio;
    }

    /* ========== LiqInjector ========== */

    function setInjectorAddress(address newInjector) public onlyDoubleOperator {
        injector = newInjector;
    }

    /* ========== MAIN FUNCTIONS ========== */

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        bool senderExcludedAddresses = isSenderExcludedAddresses(sender);
        bool recipientExcludedAddresses = isRecipientExcludedAddresses(recipient);

        if (senderExcludedAddresses == true) {  
            _transfer(sender, recipient, amount);
        } else if (recipientExcludedAddresses == true) {
            _transfer(sender, recipient, amount);
        }
        else {
            _transferWithFees(sender, recipient, amount);
        }

        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "Drip Drip, ERC20: transfer amount exceeds allowance"));
        return true;
    }    

    function _transferWithFees(address sender, address recipient, uint256 amount) internal returns (bool) {
        uint256 feesAmount = amount.mul(feesTaxRate).div(100);
        uint256 amountAfterFees = amount.sub(feesAmount);
        uint256 feesForLiquidity = feesAmount.mul(lockRatio).div(100);
        uint256 feesForBurn = feesAmount.sub(feesForLiquidity);

        burnFrom(sender, feesForBurn);
        _transfer(sender, injector, feesForLiquidity);

        _transfer(sender, recipient, amountAfterFees);
        return true;
    }
  
}