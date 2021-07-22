// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/**
 * This contract is the $PAPR ERC20 token.
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
import './interfaces/IOracle.sol';

/**
 * @title PAPR base contract
 * @notice ..
 * @author PaprPrintr's team
 */

contract PAPR is ERC20Burnable, DoubleOperator {

    /* ========== STATE VARIABLES ========== */

    // Fees
    uint256 constant public maxPriceTaxRates = 15e17;
    uint256 constant public minPriceTaxRates = 6e17;
    uint256 constant public paprMultiplierStepExpansion = 10e16; // 10 cents
    //list of fees for every price range
    mapping(uint256 => uint256) private feesTaxRate;
    uint256 public lockRatio = 70;
    //list of addresses which exclude fees
    mapping(address => bool) public senderExcludedAddresses;
    mapping(address => bool) public recipientExcludedAddresses;

    // Oracle
    address public paprOracle;
    address public papr;
    address public injector;

    /* ========== CONSTRUCTOR ========== */

    constructor() public ERC20('PAPR', 'PAPR') {
        _mint(msg.sender, 25000 * 10**18);
        // Set the array of tax rate according to the price

        // sub 0.6 = 30%
        feesTaxRate[0] = 30;
        // 0.6 - 0.7 = 29 %
        feesTaxRate[1] = 29;
        // 0.7 - 0.8 = 27 %
        feesTaxRate[2] = 27;
        // 0.8 - 0.9 = 26%
        feesTaxRate[3] = 26; 
        // 0.9 - 1.0 = 25%
        feesTaxRate[4] = 25;
        // 1.0 - 1.1 = 8 %
        feesTaxRate[5] = 8;
        // 1.1 - 1.2 = 6 %
        feesTaxRate[6] = 6;
        // 1.2 - 1.3 = 4%
        feesTaxRate[7] = 4;
        // 1.3 - 1.4 = 3%
        feesTaxRate[8] = 3;
        // 1.4 - 1.5 = 2%
        feesTaxRate[9] = 2;
        // above 1.5 = 1%
        feesTaxRate[10] = 1;
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


    //---------------- RECIPIENT -------------------//

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


     //---------------- RECIPIENT -------------------//

    // Get fees for a price range (index) :
    function getfeesTaxRate(uint256 index) public view returns(uint256) {
        return feesTaxRate[index];
    }

    // Set fees for a price range (index) :
    function setfeesTaxRate(uint256 index, uint256 fees) public onlyDoubleOperator {
        require(fees <= 40);
        feesTaxRate[index] = fees;
    }

    function setfeesLockRate(uint256 _lockRatio) public onlyDoubleOperator {
        lockRatio = _lockRatio;
    }

    function getLockRatio() public view returns(uint256) {
        return lockRatio;
    }


    // Return number of times over the cents step (paprMultiplierStepExpansion) :
    function _countTimesOverCents() internal returns (uint256) {
        uint256 paprPrice = getPaprPrice();
        if (paprPrice >= maxPriceTaxRates) {
            return 10;
        } else if (paprPrice <= minPriceTaxRates) {
            return 0;
        } else {
            uint256 count;
            paprPrice = paprPrice.sub(minPriceTaxRates);
            count = paprPrice.div(paprMultiplierStepExpansion);
            return count.add(1);
        }
    }

    /* ========== ORACLE ========== */

    // Set new Oracle on the PAPR contract
    function setpaprOracleAddress(address newOracle) public onlyDoubleOperator {
        paprOracle = newOracle;
    }
    // Reference the PAPR address to itself as an argument for the Oracle
    function setpaprAddress(address newPaprAddress) public onlyDoubleOperator {
        papr = newPaprAddress;
    }

    function setInjectorAddress(address newInjector) public onlyDoubleOperator {
        injector = newInjector;
    }

    /* ========== MAIN FUNCTIONS ========== */

    function mint(address recipient_, uint256 amount_) public onlySecondaryOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }


    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 paprPrice = getPaprPrice();
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

        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }    

    function _transferWithFees(address sender, address recipient, uint256 amount) internal returns (bool) {
        uint256 feesAmount = amount.mul(feesTaxRate[_countTimesOverCents()]).div(100);
        uint256 amountAfterFees = amount.sub(feesAmount);
        uint256 feesForLiquidity = feesAmount.mul(lockRatio).div(100);
        uint256 feesForBurn = feesAmount.sub(feesForLiquidity);

        burnFrom(sender, feesForBurn);
        _transfer(sender, injector, feesForLiquidity);

        _transfer(sender, recipient, amountAfterFees);
        return true;
    }

    /* ========== GET FUNCTIONS ========== */

    function getPaprPrice() public view returns (uint256 paprPrice) {
        try IOracle(paprOracle).consult(papr, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert("Failed to consult PAPR price from the oracle");
        }
    }

    function _updatePaprPrice() internal {
        try IOracle(paprOracle).update() {} catch {}
    }    
}